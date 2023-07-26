# frozen_string_literal: true

class TikrStockService < BaseService
  def initialize(stock, cid, tid, access_token)
    @stock = stock
    @access_token = access_token
    @cid = cid
    @tid = tid
  end

  def get_financial
    url = 'https://oljizlzlsa.execute-api.us-east-1.amazonaws.com/prod/fin'
    response = HTTParty.post(url, { 
        headers: request_headers, 
        body: request_params
      })
    raise ArgumentError, 'Fail to fetch Tikr data' unless response.ok?

    body = response.parsed_response
    financial_data = body['data']
    ids = data_items.values
    res = ids.to_h { |x| [x, []] }
    financial_data.each do |data|
      res[data['dataitemid']] << data['dataitemvalue'].to_f if ids.include?(data['dataitemid'])
    end
    result = data_items.map { |item, value| {item => res[value].length > 10 ? res[value][-11, 11] : res[value]} }.reduce(:merge)
    result.merge(get_daily_fin)
  end

  def get_daily_fin
    url = 'https://oljizlzlsa.execute-api.us-east-1.amazonaws.com/prod/daily'
    response = HTTParty.post(url, { 
      headers: request_headers, 
      body: request_params_daily
    })
    raise ArgumentError, 'Fail to fetch Tikr data' unless response.ok?

    body = response.parsed_response
    ltm = body['ltm'].group_by { |ltm| ltm[1].itself}
    res = {}
    current_year = Date.today.year
    data_items_daily.each do |key, value|
      if ltm[value].blank?
        res[key] = []
        next
      end

      year = current_year
      count = 0
      items = []
      ltm[value].reverse.each do |daily|
        break if count == 11
        next unless (daily[7] == year && (daily[8] == 3 || current_year == daily[7] || daily[8] < 3 && (current_year - year) == count)) || (count == 0 && daily[7] == (year - 1) && daily[8] == 4)

        items << daily[2].to_f
        count+= 1
        year-= 1
      end

      res[key] = items.reverse if items.present?
    end

    res
  end

  def data_items
    {
      current_ratio: 4030,
      roe: 4128,
      de: 4034,
      net_income: 15, #16, 2150
      total_stock: 342, # 3217
      total_liabilities: 1276,
      total_equities: 1275,
      npm: 4094,
      total_cash_equivalents: 1002,
      current_liabilities: 1009,
      cash_from_investing: 2005,
      capex: 2021,
      cash_from_operation: 2006,
      bvps: 4020,
      # dividend: 2074,
      eps: 142, #9
    }
  end

  def data_items_daily
    {
      bvps: 4020,
      eps: 142,
      dividend: 3058
    }
  end

  def request_params
    {
      auth: @access_token,
      cid: @cid,
      p: '1',
      repid: 1,
      tid: @tid,
      v: 'v1'
    }.to_json
  end

  def request_params_daily
    {
      auth: @access_token,
      cid: @cid,
      currency: 69,
      ntmIds: [],
      streetIds: [],
      tid: @tid,
      v: 'v2'
    }.to_json
  end

  def request_headers
    { 
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36' ,
      'Content-Type' => 'application/json',
      'Origin' => 'https://app.tikr.com',
      'Authority' => 'oljizlzlsa.execute-api.us-east-1.amazonaws.com',
      'sec-ch-ua': '".Not/A)Brand";v="99", "Google Chrome";v="103", "Chromium";v="103"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': "macOS",
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'cross-site'
    }
  end

  def self.login_tikr(driver, service)
    driver.navigate.to('https://app.tikr.com/login')
    wait = Selenium::WebDriver::Wait.new(timeout: 15)
    wait.until { driver.find_element(tag_name: 'input') }
    driver.find_elements(tag_name: 'input')[0].send_keys('williamlie8910@gmail.com')
    driver.find_elements(tag_name: 'input')[1].send_keys('Tikr.160415040')
    driver.find_element(class: 'v-btn').click

    wait.until { driver.find_element(class: 'v-toolbar') }

    access_token_key = 'CognitoIdentityServiceProvider.7ls0a83u5u94vjb2g6t6mdenik.williamlie8910@gmail.com.idToken'
    access_token = driver.execute_script("return window.localStorage")[access_token_key]

    service.update(access_token: access_token, last_update_access_token: Time.now)
  end

  def self.find_stock_id(driver, history)
    driver.find_element(css: "div[role='combobox']").click
    sleep(0.5)
    textbox = driver.find_element(css: "div[role='combobox']").find_element(css: "input[type='text']")
    textbox.clear
    textbox.send_keys(history.name)
    sleep(0.5)

    wait = Selenium::WebDriver::Wait.new(timeout: 15)
    wait.until { @driver.find_element(css: "div[role='listbox']").find_element(tag_name: 'span') }

    idx = 0
    7.times do
      raise StandardError("Not found") if idx == 6
      listbox_items = driver.find_element(css: "div[role='listbox']").find_elements(tag_name: 'span')[idx]
      if listbox_items.text.include?('IDX') && listbox_items.text.include?(stock)
        listbox_items.click
        break
      end
      idx = idx + 1
    end
    
    sleep(1)
    wait.until { driver.execute_script("return document.title").include?(history.name) }
    url = driver.execute_script("return window.location.href")
    ar_url = url.gsub("https://app.tikr.com/stock/about?",'').split('&')
    cid = ar_url[0].gsub('cid=', '').to_i
    tid = ar_url[1].gsub('tid=', '').to_i

    history.update(cid: cid, tid: tid)
  end
end
