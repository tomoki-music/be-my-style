class Singing::CheerReactionsController < Singing::BaseController
  def create
    reaction_type    = params[:reaction_type].to_s
    target_customer  = Customer.find_by(id: params[:target_customer_id])

    unless SingingCheerReaction::REACTION_TYPES.include?(reaction_type)
      render json: { error: "Invalid reaction type" }, status: :unprocessable_entity
      return
    end

    if target_customer.nil?
      render json: { error: "User not found" }, status: :not_found
      return
    end

    if target_customer == current_customer
      render json: { error: "Cannot react to yourself" }, status: :forbidden
      return
    end

    reaction = SingingCheerReaction.find_or_initialize_by(
      customer:        current_customer,
      target_customer: target_customer,
      reaction_type:   reaction_type
    )

    reacted = reaction.new_record?
    reacted ? reaction.save! : reaction.destroy!

    count = SingingCheerReaction.where(
      target_customer: target_customer,
      reaction_type:   reaction_type
    ).count

    render json: { reacted: reacted, count: count }
  end
end
