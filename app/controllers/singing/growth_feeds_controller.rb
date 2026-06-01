class Singing::GrowthFeedsController < Singing::BaseController
  def index
    @feed_items  = Singing::GrowthFeedBuilder.call
    @feed_summary = Singing::GrowthFeedSummaryBuilder.call(feed_items: @feed_items)
    customer_ids = @feed_items.map { |item| item.customer.id }
    load_reaction_data(customer_ids)
  end

  private

  def load_reaction_data(customer_ids)
    reactions = SingingCheerReaction.where(target_customer_id: customer_ids)

    @reaction_counts = reactions
      .group(:target_customer_id, :reaction_type)
      .count
      .each_with_object(Hash.new { |h, k| h[k] = {} }) do |((cid, type), count), hash|
        hash[cid][type] = count
      end

    @my_reactions = reactions
      .where(customer: current_customer)
      .group_by(&:target_customer_id)
      .transform_values { |rs| rs.map(&:reaction_type).to_set }
  end
end
