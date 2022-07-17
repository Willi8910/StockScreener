# frozen_string_literal: true

class YahooStockService < BaseService
  def self.get_yahoo_hystorical_price(stock, year)
    @prices = []

    current_time = Time.new.to_i
    timeframe = '1mo'
    url = "https://query2.finance.yahoo.com/v8/finance/chart/#{stock}.JK?formatted=true&crumb=IX3MvaQZcGz&lang=en-US&region=US&includeAdjustedClose=true&interval=#{timeframe}&period1=1354320000&period2=#{current_time}&events=capitalGain%7Cdiv%7Csplit&useYfid=true&corsDomain=finance.yahoo.com"
    response = HTTParty.get(url, { headers: { 'User-Agent' => 'Httparty' } })
    raise ArgumentError, "Stocks data is not found" if response.not_found?
    raise StandardError, 'Fail to fetch Yahoo data' unless response.ok?

    body = response.parsed_response
    type = body['chart']['result'][0]['meta']['instrumentType']
    raise StandardError, 'This code is not for stock' unless type == "EQUITY"
    
    timestamps = body['chart']['result'][0]['timestamp']
    prices_response = body['chart']['result'][0]['indicators']['quote'][0]['close']
    ttm_date = Date.today.change({ month: ((Date.today.month - 1) / 3) * 3, day: 1 })

    year_index = 0
    timestamps.each_with_index do |timestamp, index|
      if year[year_index] == 'TTM'
        if Time.at(timestamp).to_date == ttm_date
          @prices << prices_response[index]
          break
        end
      elsif Time.at(timestamp).to_date == Date.new(year[year_index], 12, 1)
        @prices << prices_response[index]
        year_index += 1
      elsif Time.at(timestamp).to_date > Date.new(year[year_index], 12, 1)
        while Time.at(timestamp).to_date > Date.new(year[year_index], 12, 1)
          @prices << 0
          year_index += 1
          break if year[year_index] == 'TTM'
        end
      end
    end

    @prices
  end
end
