# frozen_string_literal: true

class StockServiceV2 < BaseService
  def initialize(stock, data = nil)
    @stock = stock
    @data = data
  end

  def get_prices
    setup_year
    YahooStockService.get_yahoo_hystorical_price(@stock, @year)
  end

  def get_bei_stock_list
    configure_driver
    @driver.navigate.to('https://idx.co.id/perusahaan-tercatat/profil-perusahaan-tercatat/detail-profile-perusahaan-tercatat/?kodeEmiten=ABMM')
    @wait.until { @driver.find_element(id: 'emitenList') }
    list_stock = @driver.find_element(id: 'emitenList').find_elements(tag_name: 'option')
    list_stock.shift
    print("Start looping")

    list_stock.each do |stock|
      sleep(0.5)
      print("create or find: "+stock.text)
      History.where(name: stock.attribute('value'), full_name: stock.text).first_or_create
    end
    @driver.close
  end

  def get_tikr_stock_id
    configure_driver
    @driver.navigate.to('https://app.tikr.com/login')
    @wait.until { @driver.find_element(tag_name: 'input') }
    @driver.find_elements(tag_name: 'input')[0].send_keys('williamlie8910@gmail.com')
    @driver.find_elements(tag_name: 'input')[1].send_keys('Tikr.160415040')
    @driver.find_element(class: 'v-btn').click

    @wait.until { @driver.find_element(class: 'v-toolbar') }
    @wait = Selenium::WebDriver::Wait.new(timeout: 5)
    History.where(cid: nil).each do |history|
      begin
        puts "Get stock id for " + history.name
        TikrStockService.find_stock_id(@driver, history)
      rescue StandardError
        puts "Fail Fetching for stock " + history.name
        next
      end
    end
  end

  def fetch_tikr_fin_data
    configure_driver

    @service = ExternalService.find_by(name: 'tikr')
    if @service.access_token.nil? || @service.last_update_access_token < 1.hour.ago
      TikrStockService.login_tikr(@driver, @service)
    end

    setup_year
    History.where.not(cid: nil, tid: nil).each do |history|
      begin
        @stock = history.name
        @history = history
        puts "Start get financial data of Stock " + @stock
        @prices = YahooStockService.get_yahoo_hystorical_price(@stock, @year)
        positive_index = @prices.find_index {|x| x.positive? }
        if positive_index.blank?
          puts "Invalid Stock, skipping"
          history.destroy
          next
        end
        @prices = @prices[positive_index, @prices.length]

        setup_financial_tikr
        if @eps.blank? && @pbv.blank? && @roe.blank?
          puts "Invalid Stock, skipping"
          history.destroy
          next
        end
        data = { 'valuation' => valuation, 'price' => calculate_fair_price, 'year' => { 'year10' => @year } }
        history.update(data: JSON[data])
        puts "Successfully get data"
        puts ""
      rescue StandardError => e
        puts e.message
        puts "Error get financial data of Stock " + @stock
        puts ""
      end
    end
    @driver.close
  # rescue ArgumentError => e
  #   close_driver

  #   { message: e.message }
  # rescue StandardError => e
  #   close_driver
  #   puts e

  #   { message: 'Something wrong is happen please try again' }
  end

  def perform
    configure_driver

    @history = History.where(name: @stock).first_or_initialize
    @service = ExternalService.find_by(name: 'tikr')
    setup_year
    @prices = YahooStockService.get_yahoo_hystorical_price(@stock, @year)
    positive_index = @prices.find_index {|x| x.positive? }
    @prices = @prices[positive_index, @prices.length]

    if @history&.cid.nil? || @history&.tid.nil? || 
      @service.access_token.nil? || @service.last_update_access_token < 1.hour.ago
      scrape_tikr
    end

    setup_financial_tikr

    data = { 'valuation' => valuation, 'price' => calculate_fair_price, 'year' => { 'year10' => @year } }
    @driver.close
    @history.update(data: JSON[data])
    data
  rescue ArgumentError => e
    close_driver

    { message: e.message }
  rescue StandardError => e
    close_driver
    puts e

    { message: 'Something wrong is happen please try again' }
  end

  def setup_year
    initial_year = Date.today.year
    initial_year -= 1 if Date.today.month > 3

    @year = ((initial_year - 9)..initial_year).to_a
    @year << 'TTM'
  end

  def setup_financial_tikr
    @fin = TikrStockService.new(@stock, @history.cid, @history.tid, @service.access_token).get_financial

    # perlu update:
    # - capex ratio: operating cashflow / capex
    # 
    @current_ratio, @roe, @de,
    @net_income, @total_stock, @total_liabilities, 
    @total_equities, @npm, @total_cash_equivalents,
    @current_liabilities, @cash_from_investing, @capex,
    @cash_from_operation, @bvps, @eps, @dividend = *@fin.values

    # @de = divide_array(@total_liabilities, @total_equities)
    @eps = clean_array_tikr(@eps)
    @de = clean_array_tikr(@de)
    @per = divide_array(@prices, @eps)
    @pbv = divide_array(@prices, @bvps)
    @dividend_yield = divide_array(@dividend, @prices).map { |item| item * 100}
    @cap_ex_ratio = normalize_zero(divide_array(@capex, @cash_from_investing).map { |item| item * 100})
    @cash_ratio = divide_array(@total_cash_equivalents, @current_liabilities)
    @fcf = addition_array(@capex, @cash_from_operation)
  end

  def valuation
    valuation = {
      'de' => { 'D / E' => @de, 'Limit Top' => set_limit(@de, 0.5) },
      'cr' => { 'Current Ratio' => @current_ratio, 'Limit Bottom' => set_limit(@current_ratio, 1.5),
                'Limit Top' => set_limit(@current_ratio, 2.5) },
      'roe' => { 'ROE' => @roe, 'Limit Bottom' => set_limit(@roe, 8) },
      'bvps' => { 'BVPS' => @bvps },
      'dividend' => { 'Dividend' => @dividend },
      'dividend_yield' => { 'Dividend Yield' => @dividend_yield },
      'eps' => { 'EPS' => @eps },
      'per' => { 'PER' => @per, 'Limit Top' => set_limit(@per, 15) },
      'pbv' => { 'PBV' => @pbv, 'Limit Top' => set_limit(@pbv, 1.5) },
      'npm' => { 'NPM' => @npm, 'Limit Bottom' => set_limit(@npm, 8) },
      'capex' => { 'CAPEX' => @cap_ex_ratio, 'Limit Top' => set_limit(@cap_ex_ratio, 20) },
      'cash_ratio' => { 'Cash Ratio' => @cash_ratio, 'Limit Bottom' => set_limit(@cash_ratio, 0.5) },
      'fcf' => { 'FCF' => @fcf, 'Limit Bottom' => set_limit(@fcf, 0) }
    }
  end

  def calculate_fair_price
    query = BasicYahooFinance::Query.new
    stock_info = query.quotes("#{@stock}.JK")["#{@stock}.JK"]

    current_price = @prices.last

    # PER Valuation
    mean_per_ttm = @per.sum(0.0) / @per.size
    eps_ttm = @eps[-1]
    if eps_ttm < 0 
      per_valuation_fair_price = 0
      per_valuation_mos = 0
    else
      per_valuation_fair_price = mean_per_ttm * eps_ttm
      per_valuation_fair_price = validate_price(per_valuation_fair_price)
      per_valuation_mos = calculate_mos(current_price, per_valuation_fair_price)
    end

    # PBV Ratio Method
    current_bvps = @bvps.last
    mean_pbv = @pbv.sum(0.0) / @pbv.size
    if mean_pbv < 0
      pbv_ratio_fair_price = 0
      pbv_ratio_mos = 0
    else
      pbv_ratio_fair_price = current_bvps * mean_pbv
      pbv_ratio_fair_price = validate_price(pbv_ratio_fair_price)
      pbv_ratio_mos = calculate_mos(current_price, pbv_ratio_fair_price)
    end

    # Benjamin Graham Formula
    growth_constant = 7
    phei = ExternalService.find_by(name: 'phei')
    if phei.obligation_last_updated.blank? || phei.obligation_last_updated < 1.day.ago
      # https://www.phei.co.id/Data/HPW-dan-Imbal-Hasil
      # IGYSC tab
      phei_link = 'https://www.phei.co.id/Data/HPW-dan-Imbal-Hasil'
      @driver.navigate.to(phei_link)
      @wait.until { @driver.find_element(id: 'dnn_ctr1477_GovernmentBondBenchmark_gvTenor1') }
      yield_obligation_government_10y = @driver.find_element(id: 'dnn_ctr1477_GovernmentBondBenchmark_gvTenor1').find_elements(tag_name: 'tr')[11].find_elements(tag_name: 'td')[1].text.gsub(
        ',', ''
      ).to_f

      # Corporate bond tab
      corporate_bond_link = 'https://www.phei.co.id/Data/HPW-dan-Imbal-Hasil#YieldByTenor'
      @driver.navigate.to(corporate_bond_link)
      @driver.find_element(xpath: '//*[@id="ui-id-3"]').click
      @wait.until { @driver.find_element(id: 'dnn_ctr1477_GovernmentBondBenchmark_gvCSM') }
      yield_obligation_corporate_10y = @driver.find_element(id: 'dnn_ctr1477_GovernmentBondBenchmark_gvCSM').find_elements(tag_name: 'tr')[11].find_elements(tag_name: 'td')[3].text.gsub(
        ',', ''
      ).to_f
      phei.update(yog: yield_obligation_government_10y, yoc: yield_obligation_corporate_10y, obligation_last_updated: Time.now)
    else
      yield_obligation_government_10y = phei.yog
      yield_obligation_corporate_10y = phei.yoc
    end

    # Calculate EPS expected Growth Rate
    start_idx = 0
    last_eps = @eps[-2]
    if last_eps.present? && last_eps > 0
      @eps.count.times.each do |i|
        if (@eps[i]).positive?
          start_idx = i
          break
        end
      end
      eps_expected_growth_rate = (((last_eps / @eps[start_idx])**(1.to_f / (@eps.size - 1 - start_idx))) - 1) * 100
      bg_fair_price = last_eps.to_f * (growth_constant + eps_expected_growth_rate) * yield_obligation_government_10y / 
                      yield_obligation_corporate_10y
      bg_fair_price = validate_price(bg_fair_price)
      
    else
      bg_fair_price = 0
    end
    bg_mos = calculate_mos(current_price, bg_fair_price)

    { 'Method' => ['PER Valuation', 'PBV Ratio Method', 'Benjamin Graham Formula'],
      'Current Price' => [current_price, current_price, current_price],
      'Fair Price' => [per_valuation_fair_price, pbv_ratio_fair_price, bg_fair_price],
      'MOS' => [per_valuation_mos, pbv_ratio_mos, bg_mos] }
  end

  def configure_driver
    # if Rails.env.production?
    #   chrome_bin_path = ENV.fetch('GOOGLE_CHROME_SHIM', nil)
    #   options.binary = chrome_bin_path if chrome_bin_path
    # else
    # end
    # options.add_argument('--headless')
    # options.add_argument('--disable-dev-shm-usage')
    # options.add_argument('--no-sandbox')
    options = Selenium::WebDriver::Chrome::Options.new
    Selenium::WebDriver::Chrome.driver_path = '/Users/williamlie/Downloads/chromedriver'
    @driver = Selenium::WebDriver.for :chrome, options: options
    @wait = Selenium::WebDriver::Wait.new(timeout: 60)
  end

  def scrape_tikr
    TikrStockService.login_tikr(@driver, @service)
    return if @history&.cid.present? || @history&.tid.present?

    TikrStockService.find_stock_id(@driver, @history)
  end

  def divide_array(numerator, denominator)
    return [] unless numerator && denominator
    denominator = denominator[-numerator.length, numerator.length] if numerator.length < denominator.length
    numerator = numerator[-denominator.length, denominator.length] if numerator.length > denominator.length
    numerator.count.times.map { |i| !denominator[i].zero? ? numerator[i] / denominator[i] : 0 }
  end

  def addition_array(num1, num2)
    return [] if num1.blank? && num2.blank?
    return num1 if num2.blank?
    return num2 if num1.blank?
    num2 = num2[-num1.length, num1.length] if num1.length < num2.length

    num1.count.times.map { |i| num1[i] + num2[i] }
  end

  def set_limit(items, item)
    return [] if items.blank?
    items.count.times.map { |_n| item }
  end

  def calculate_mos(price, fair_price)
    return (fair_price - price) / fair_price * 100 if fair_price > price

    0
  end

  def validate_price(price)
    return 0 if price.infinite? || price.instance_of?(Complex) || price.nan? || price.negative?

    price
  end

  def normalize_zero(array)
    array.map { |item| item > 0 ? item : 0 }
  end

  def clean_array_tikr(array)
    res = []
    array.each do |item|
      res << item if item != 1.11
    end

    res
  end

  def close_driver
    @driver.close
  rescue StandardError
    puts 'driver already closed'
  end
end
