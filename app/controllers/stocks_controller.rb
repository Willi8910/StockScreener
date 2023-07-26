# frozen_string_literal: true

class StocksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stock, only: %i[show update destroy save_favourite delete_favourite]
  before_action :validate_stock_params, only: %i[create]

  # GET /stocks
  def index
    @stocks = current_user.stocks.order(created_at: :desc)
    stocks_name = @stocks.pluck(:name)
    stock_info = YahooStockService.get_curret_stock_prices(stocks_name)

    render json: merge_attributes(stock_info)
  end

  def save_favourite
    return render json: 'Stock is not exist', status: 404 if @stock.nil?

    @stock.update(favourite: true)
    render json: 'Success add new Favourite'
  end

  def delete_favourite
    return render json: 'Stock is not exist', status: 404 if @stock.nil?

    @stock.update(favourite: false)
    render json: 'Success remove Favourite'
  end

  # POST /stocks
  def create
    stock_result = History.where.not(data: nil).where(name: params[:stock]).first
    return render json: 'Stock is not exist', status: 404 if stock_result.nil?
    
    save_stock(JSON[stock_result.data])
    data = JSON[stock_result.data]
    data["valuation"]["prices"] = { 'Price' => StockServiceV2.new(params[:stock]).get_prices}
    render json: data
  end

  def recommendation
    recs = StockRecommend.includes(:history).order(rating: :desc)

    stocks_name = History.where(id: recs.pluck(:history_id)).pluck(:name)
    stock_info = YahooStockService.get_curret_stock_prices(stocks_name)
    render json: serialize_recommendation(recs, stock_info)
  end

  def update
    if @stock.update(value: params[:value])
      return render json: "Successfully update stock"
    else
      return render json: 'Something wrong is happened, please try again', status: 422
    end
  end

  # DELETE /stocks/1
  def destroy
    return render json: 'Stock is not exist', status: 404 if @stock.nil?

    @stock.destroy
    render json: 'Success remove Stock'
  end

  private

  def set_stock
    @stock = Stock.find_by_id(params[:id])
  end

  def stock_params
    params.fetch(:stock, {}).permit(:name, :value, :pb_fair_value, :pe_fair_value, :benjamin_fair_value)
  end

  def validate_stock_params
    return if params[:stock]

    render json: { message: 'Stock parameter is required' }, status: :bad_request
  end

  def compare_month
    Time.new(@history.updated_at.strftime('%Y'),
             @history.updated_at.strftime('%m')) != Time.new(Time.now.strftime('%Y'), Time.now.strftime('%m'))
  end

  def update_regular_price; end

  def save_stock(stock_result)
    price_result = stock_result['price']['Fair Price']
    @stock = current_user.stocks.find_or_create_by(name: params[:stock])
    value = @stock.previously_new_record? ? stock_result['price']['Current Price'][0] : @stock.value
    @stock.update(value: value, pb_fair_value: price_result[1],
                  pe_fair_value: price_result[0],
                  benjamin_fair_value: price_result[2],
                  chart: stock_result['valuation']['bvps']['BVPS'].join(' '))
  end

  def save_new_history(stock_result)
    History.create(name: params[:stock], data: JSON[stock_result])
  end

  def merge_attributes(quotes)
    @stocks.map do |stock|
      { name: stock.name, value: stock.value, pb_fair_value: stock.pb_fair_value,
        pe_fair_value: stock.pe_fair_value, benjamin_fair_value: stock.benjamin_fair_value,
        current_value: quotes["#{stock.name}.JK"],
        difference: calculate_difference(stock.value, quotes["#{stock.name}.JK"]),
        chart: stock.chart.split, favourite: stock.favourite, id: stock.id }
    end
  end

  def serialize_recommendation(recs, quotes)
    recs.map do |res|
      stock = res.history
      { 
        name: stock.name,
        current_value: quotes["#{stock.name}.JK"],
        price: JSON[stock.data]["price"],
        rating: res.rating
      }
    end
  end

  def calculate_difference(value, current_value)
    ((current_value - value) / current_value * 100).round(2)
  end
end
