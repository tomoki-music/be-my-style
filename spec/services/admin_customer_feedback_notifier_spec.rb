require "rails_helper"

RSpec.describe AdminCustomerFeedbackNotifier do
  let(:customer) { create(:customer) }

  describe ".call" do
    it "全管理者宛に customer_feedback_created メールをキューイングすること" do
      create_list(:admin, 2)
      feedback = create(:customer_feedback, customer: customer)

      expect do
        described_class.call(feedback)
      end.to have_enqueued_mail(AdminNotificationMailer, :customer_feedback_created).twice
    end

    it "管理者が存在しない場合は何もしないこと" do
      feedback = create(:customer_feedback, customer: customer)

      expect do
        described_class.call(feedback)
      end.not_to have_enqueued_mail(AdminNotificationMailer, :customer_feedback_created)
    end

    it "未保存の feedback では通知しないこと" do
      create(:admin)
      feedback = build(:customer_feedback, customer: customer)

      expect do
        described_class.call(feedback)
      end.not_to have_enqueued_mail(AdminNotificationMailer, :customer_feedback_created)
    end

    it "nil を渡してもエラーにならないこと" do
      create(:admin)

      expect { described_class.call(nil) }.not_to raise_error
    end
  end
end
