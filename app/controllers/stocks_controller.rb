# frozen_string_literal: true

class StocksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stock, only: %i[show update destroy]
  before_action :validate_stock_params, only: %i[create]

  # GET /stocks
  def index
    @stocks = current_user.stocks

    render json: @stocks
  end

  # GET /stocks/1
  def show
    render json: @stock
  end

  # POST /stocks
  def create
    stock_result = StockService.new(params[:stock]).screening
    @stock = current_user.stocks.create(name: params[:stock], value: stock_result['price']['Current Price'][0],
                                        pb_fair_value: stock_result['price']['Current Price'][0],
                                        pe_fair_value: stock_result['price']['Current Price'][1],
                                        benjamin_fair_value: stock_result['price']['Current Price'][2])

    render json: stock_result
  end

  # PATCH/PUT /stocks/1
  def update
    if @stock.update(stock_params)
      render json: @stock
    else
      render json: @stock.errors, status: :unprocessable_entity
    end
  end

  # DELETE /stocks/1
  def destroy
    @stock.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_stock
    @stock = Stock.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def stock_params
    params.fetch(:stock, {}).permit(:name, :value, :pb_fair_value, :pe_fair_value, :benjamin_fair_value)
  end

  def validate_stock_params
    return if params[:stock]

    render json: { message: 'Stock parameter is required' }, status: :bad_request
  end
end
