# frozen_string_literal: true

class StockService < BaseService
  def initialize(stock, data = nil)
    @stock = stock
    @data = data
  end

  def screening
    get_stock
  end

  def update_history
    query = BasicYahooFinance::Query.new
    stock_info = query.quotes("#{@stock}.JK")["#{@stock}.JK"]
    current_price = stock_info['regularMarketPrice']

    stock_result = JSON[@data]
    stock_result['price']['Current Price'] = [current_price, current_price, current_price]

    fair_prices = stock_result['price']['Fair Price']
    per_valuation_mos = calculate_mos(current_price, fair_prices[0])
    pbv_ratio_mos = calculate_mos(current_price, fair_prices[1])
    bg_ratio_mos = calculate_mos(current_price, fair_prices[2])

    stock_result['price']['MOS'] = [per_valuation_mos, pbv_ratio_mos, bg_ratio_mos]

    stock_result
  rescue StandardError
    { message: 'Something wrong is happen please try again' }
  end

  # rubocop:disable Metrics
  def get_stock
    options = Selenium::WebDriver::Chrome::Options.new
    if Rails.env.production?
      chrome_bin_path = ENV.fetch('GOOGLE_CHROME_SHIM', nil)
      options.binary = chrome_bin_path if chrome_bin_path
    else
      Selenium::WebDriver::Chrome.driver_path = 'C:\\chromedriver.exe'
    end
    options.add_argument('--headless')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--no-sandbox')
    @driver = Selenium::WebDriver.for :chrome, options: options

    stock = @stock
    link = "http://financials.morningstar.com/balance-sheet/bs.html?t=#{stock}&region=idn&culture=en-US"
    @driver.navigate.to(link)

    raise ArgumentError, 'Stock does not exist' if @driver.find_elements(class_name: 'error__message').count.positive?

    year = find_year5
    total_liabilities = financials_get_row('data_ttg5')
    current_liabilities = financials_get_row('data_ttgg5')
    total_equity = financials_get_row('data_ttg8')
    total_cash = financials_get_row('data_ttgg1')

    key_ratios_link = "http://financials.morningstar.com/ratios/r.html?t=#{stock}&region=idn&culture=en-US"
    @driver.navigate.to(key_ratios_link)
    # Profitability Tab
    sleep(2)
    year10 = find_year_10

    roe = ratios_get_row_by_css_selector('i26')
    revenue = ratios_get_row_by_css_selector('i0')
    bvps = ratios_get_row_by_css_selector('i8')
    dividend = ratios_get_row_by_css_selector('i6')
    @eps = ratios_get_row_by_css_selector('i5')
    net_income = ratios_get_row_by_css_selector('i4')
    fcf = ratios_get_row_by_css_selector('i11')
    net_profit_margin = divide_array(net_income, revenue)
    npm = net_profit_margin.map { |n| n * 100 }

    # Cashflow Tab
    @driver.find_element(css: '#keyStatWrap > div > ul > li:nth-child(3) > a').click
    cap_ex_ratio = ratios_get_row_by_css_selector('i42')

    # Financial Health Tab
    @driver.find_element(css: '#keyStatWrap > div > ul > li:nth-child(4) > a').click
    current_ratio = ratios_get_row_by_css_selector('i65')

    valuation_link = "http://financials.morningstar.com/valuation/price-ratio.html?t=#{stock}&region=idn&culture=en-US"
    @driver.navigate.to(valuation_link)
    sleep(5)
    @pe = valuation_get_row_by_css_selector('#valuation_history_table > tbody > tr:nth-child(2)')
    @pbv = valuation_get_row_by_css_selector('#valuation_history_table > tbody > tr:nth-child(5)')

    debt_per_equity = divide_array(total_liabilities, total_equity)
    cash_ratio = divide_array(total_cash, current_liabilities)

    price = calculate_fair_price
    @driver.close

    valuation = {
      'de' => { 'D / E' => debt_per_equity, 'Limit' => set_limit(debt_per_equity, 0.5) },
      'cr' => { 'Current Ratio' => current_ratio, 'Limit Top' => set_limit(current_ratio, 1.5),
                'Limit Bottom' => set_limit(current_ratio, 2.5) },
      'roe' => { 'ROE' => roe, 'Limit' => set_limit(roe, 8) },
      'bvps' => { 'BVPS' => bvps },
      'dividend' => { 'Dividend' => dividend },
      'eps' => { 'EPS' => @eps },
      'per' => { 'PER' => @pe, 'Limit' => set_limit(@pe, 15) },
      'pbv' => { 'PBV' => @pbv, 'Limit' => set_limit(@pbv, 1.5) },
      'npm' => { 'NPM' => npm, 'Limit' => set_limit(npm, 8) },
      'capex' => { 'CAPEX' => cap_ex_ratio, 'Limit' => set_limit(cap_ex_ratio, 20) },
      'cash_ratio' => { 'Cash Ratio' => cash_ratio, 'Limit' => set_limit(cash_ratio, 0.5) },
      'fcf' => { 'FCF' => fcf, 'Limit' => set_limit(fcf, 0) }
    }
    { 'valuation' => valuation, 'price' => price, 'year' => { 'year5' => year, 'year10' => year10 } }
  rescue ArgumentError => e
    close_driver

    { message: e.message }
  rescue StandardError => e
    close_driver
    puts e

    { message: 'Something wrong is happen please try again' }
  end

  def calculate_fair_price
    query = BasicYahooFinance::Query.new
    stock_info = query.quotes("#{@stock}.JK")["#{@stock}.JK"]

    current_price = stock_info['regularMarketPrice']

    # PER Valuation
    mean_per_ttm = @pe.sum(0.0) / @pe.size
    eps_ttm = @eps[-1]
    per_valuation_fair_price = mean_per_ttm * eps_ttm
    per_valuation_fair_price = validate_price(per_valuation_fair_price)
    per_valuation_mos = calculate_mos(current_price, per_valuation_fair_price)

    # PBV Ratio Method
    current_bvps = stock_info['bookValue']
    mean_pbv = @pbv.sum(0.0) / @pbv.size
    pbv_ratio_fair_price = current_bvps * mean_pbv
    pbv_ratio_fair_price = validate_price(pbv_ratio_fair_price)
    pbv_ratio_mos = calculate_mos(current_price, pbv_ratio_fair_price)

    # Benjamin Graham Formula
    # https://www.phei.co.id/Data/HPW-dan-Imbal-Hasil
    # IGYSC tab
    yield_obligation_government_10y = 6.68
    # Corporate bond tab
    yield_obligation_corporate_10y = 7.75
    growth_constant = 7

    # Calculate EPS expected Growth Rate
    start_idx = 0
    last_eps = @eps[-2]
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
    bg_mos = calculate_mos(current_price, bg_fair_price)

    { 'Method' => ['PER Valuation', 'PBV Ratio Method', 'Benjamin Graham Formula'],
      'Current Price' => [current_price, current_price, current_price],
      'Fair Price' => [per_valuation_fair_price, pbv_ratio_fair_price, bg_fair_price],
      'MOS' => [per_valuation_mos, pbv_ratio_mos, bg_mos] }
  end
  # rubocop:enable Metrics

  def financials_get_row(id)
    elements = @driver.find_element(id: id).find_elements(tag_name: 'div')
    elements.map { |number| (number.attribute('rawvalue') == '-' ? 0 : number.attribute('rawvalue').to_f) }
  end

  def financials_get_row_text(id)
    elements = @driver.find_element(id: id).find_elements(tag_name: 'div')
    elements.map(&:text)
  end

  def ratios_get_row_by_css_selector(css_selector)
    elements = @driver.find_elements(css: "td[headers$='#{css_selector}']")
    elements.map do |number|
      valid_float(number.text.gsub(',', '')) ? number.text.gsub('—', '-').gsub(',', '').to_f : 0
    end
  end

  def valuation_get_row_by_css_selector(css_selector)
    elements = @driver.find_element(css: css_selector).find_elements(xpath: './/*')
    elements.shift
    elements.map { |number| valid_float(number.text) ? number.text.gsub('—', '-').to_f : 0 }
  end

  def valid_float(number)
    true if Float number
  rescue StandardError
    false
  end

  def set_limit(items, item)
    items.count.times.map { |_n| item }
  end

  def divide_array(numerator, denominator)
    numerator.count.times.map { |i| denominator[i].positive? ? numerator[i] / denominator[i] : 0 }
  end

  def calculate_mos(price, fair_price)
    return (fair_price - price) / fair_price * 100 if fair_price > price

    0
  end

  def validate_price(price)
    return 0 if price.infinite? || price.nan? || price.negative?

    price
  end

  def find_year_10
    11.times.map { |n| @driver.find_element(id: "Y#{n}").text }
  rescue StandardError
    sleep(2)
    find_year_10
  end

  def find_year5
    financials_get_row_text('Year')
  rescue StandardError
    sleep(2)
    find_year5
  end

  def close_driver
    @driver.close
  rescue StandardError
    puts 'driver already closed'
  end
end
