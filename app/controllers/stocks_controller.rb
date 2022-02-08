# frozen_string_literal: true

class StocksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stock, only: %i[show update destroy]
  before_action :validate_stock_params, only: %i[create]

  # GET /stocks
  def index
    @stocks = current_user.stocks.order(created_at: :desc)
    stocks_name = @stocks.pluck(:name).map { |stock| "#{stock}.JK" }
    query = BasicYahooFinance::Query.new
    stock_info = query.quotes(stocks_name)

    render json: merge_attributes(stock_info)
  end

  # POST /stocks
  def create
    stock_result = StockService.new(params[:stock]).screening
    return render json: stock_result, status: 500 if stock_result.key?(:message)

    save_stock(stock_result)
    render json: stock_result
  end

  # DELETE /stocks/1
  def destroy
    @stock.destroy
  end

  private

  def set_stock
    @stock = Stock.find(params[:id])
  end

  def stock_params
    params.fetch(:stock, {}).permit(:name, :value, :pb_fair_value, :pe_fair_value, :benjamin_fair_value)
  end

  def validate_stock_params
    return if params[:stock]

    render json: { message: 'Stock parameter is required' }, status: :bad_request
  end

  def save_stock(stock_result)
    price_result = stock_result['price']['Fair Price']
    @stock = current_user.stocks.find_or_create_by(name: params[:stock])
    @stock.update(value: stock_result['price']['Current Price'][0],
                  pb_fair_value: price_result[1],
                  pe_fair_value: price_result[0],
                  benjamin_fair_value: price_result[2],
                  chart: stock_result['valuation']['bvps']['BVPS'].join(' '))
  end

  def merge_attributes(quotes)
    @stocks.map do |stock|
      { name: stock.name, value: stock.value, pb_fair_value: stock.pb_fair_value,
        pe_fair_value: stock.pe_fair_value, benjamin_fair_value: stock.benjamin_fair_value,
        current_value: quotes["#{stock.name}.JK"]['regularMarketPrice'],
        difference: calculate_difference(stock.value, quotes["#{stock.name}.JK"]['regularMarketPrice']),
        chart: stock.chart.split(' ') }
    end
  end

  def calculate_difference(value, current_value)
    ((current_value - value) / current_value * 100).round(2)
  end
end
