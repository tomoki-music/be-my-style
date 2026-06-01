class Singing::CheersController < Singing::BaseController
  def index
    @summary          = Singing::EncouragementSummaryBuilder.call(current_customer)
    @recent_reactions = current_customer.received_singing_cheer_reactions
                                        .includes(:customer)
                                        .order(created_at: :desc)
                                        .limit(30)
  end
end
