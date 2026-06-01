class Singing::CoachLettersController < Singing::BaseController
  before_action :authenticate_customer!

  def show
    @letter        = Singing::CoachLetterBuilder.call(current_customer)
    @is_premium    = current_customer.has_feature?(:singing_coach_letter_premium)
  end
end
