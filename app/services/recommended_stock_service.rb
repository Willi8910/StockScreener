# frozen_string_literal: true

class RecommendedStockService < BaseService
    def self.generate 
        StockRecommend.destroy_all
        histories = History.where.not(data: nil)

        rec = []
        histories.each do |stock|
            mos = JSON[stock.data]["price"]["MOS"]
            threshold = 15
            next if mos.filter { |s| s <= threshold }.present?

            rating = mos.sum(0.0) / mos.size
            StockRecommend.create(rating: rating, history: stock)
        end
    end
end