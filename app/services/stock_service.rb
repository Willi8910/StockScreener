# frozen_string_literal: true

class StockService < BaseService
  def initialize(stock)
    @stock = stock
  end

  def screening
    get_stock
  end

  def get_stock
    Selenium::WebDriver::Chrome.driver_path = 'C:\\chromedriver.exe'
    @driver = Selenium::WebDriver.for :chrome

    stock = @stock
    link = "http://financials.morningstar.com/balance-sheet/bs.html?t=#{stock}&region=idn&culture=en-US"
    @driver.navigate.to(link)
    year = financials_get_row_text('Year')
    total_liabilities = financials_get_row('data_ttg5')
    current_liabilities = financials_get_row('data_ttgg5')
    total_equity = financials_get_row('data_ttg8')
    total_cash = financials_get_row('data_ttgg1')

    key_ratios_link = "http://financials.morningstar.com/ratios/r.html?t=#{stock}&region=idn&culture=en-US"
    @driver.navigate.to(key_ratios_link)
    # Profitability Tab
    sleep(2)
    year10 = 11.times.map { |n| @driver.find_element(id: "Y#{n}").text }

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
    { 'valuation' => valuation, 'price' => price, 'year' => {'year5' => year, 'year10' => year10} }
  end

  def calculate_fair_price()
    query = BasicYahooFinance::Query.new
    stock_info = query.quotes("#{@stock}.JK")["#{@stock}.JK"]

    current_price = stock_info['regularMarketPrice']

    # PER Valuation
    mean_per_ttm = @pe.sum(0.0) / @pe.size
    eps_ttm = @eps[-1]
    per_valuation_fair_price = mean_per_ttm * eps_ttm
    per_valuation_mos = calculate_mos(current_price, per_valuation_fair_price)

    # PBV Ratio Method
    current_bvps = stock_info['bookValue']
    mean_pbv = @pbv.sum(0.0) / @pbv.size
    pbv_ratio_fair_price = current_bvps * mean_pbv
    pbv_ratio_mos = calculate_mos(current_price, pbv_ratio_fair_price)

    # Benjamin Graham Formula
    # http://www.ibpa.co.id/
    # xpath = '//*[@id="dnn_ctr504_ListGovernmentBond_gvTenor1"]/tbody/tr[12]/td[3]'
    # http://www.worldgovernmentbonds.com/country/indonesia/#:~:text=The%20Indonesia%2010Y%20Government%20Bond,according%20to%20Standard%20%26%20Poor's%20agency.
    # @driver.navigate.to('http://ibpa.co.id/DataPasarSuratUtang/HargadanYieldHarian/tabid/84/Default.aspx')
    yield_obligation_government_10y = 6.492
    # (driver.find_element(xpath: xpath).text).to_f
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
    eps_expected_growth_rate = (((last_eps / @eps[start_idx])**(1 / (@eps.size - 1 - start_idx))) - 1) * 100
    bg_fair_price = last_eps * (growth_constant + eps_expected_growth_rate) * yield_obligation_government_10y /
                    yield_obligation_corporate_10y
    bg_mos = calculate_mos(current_price, bg_fair_price)

    { 'Method' => ['PER Valuation', 'PBV Ratio Method', 'Benjamin Graham Formula'],
              'Current Price' => [current_price, current_price, current_price],
              'Fair Price' => [per_valuation_fair_price, pbv_ratio_fair_price, bg_fair_price],
              'MOS' => [per_valuation_mos, pbv_ratio_mos, bg_mos] }
  end

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
    numerator.count.times.map { |i| numerator[i] / denominator[i] }
  end

  def calculate_mos(price, fair_price)
    (fair_price - price) / fair_price * 100
  end
end
