require 'rails_helper'

RSpec.describe SendEntryInvitationJob do
  let(:invitation) { FactoryBot.create(:entry_invitation, status: :pending) }

  describe '#perform' do
    it 'メールを1通送信し、statusをdeliveredに更新する' do
      expect {
        described_class.perform_now(invitation.id)
      }.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(invitation.reload.status).to eq "delivered"
      expect(ActionMailer::Base.deliveries.last.to).to eq [invitation.customer.email]
    end

    it 'すでにpendingでない場合は送信しない（二重配信防止）' do
      invitation.update!(status: :delivered)

      expect {
        described_class.perform_now(invitation.id)
      }.not_to change { ActionMailer::Base.deliveries.size }
    end

    it '送信失敗時はstatus=failedと理由を記録し、例外を再送出しない' do
      allow(EntryInvitationMailer).to receive(:invite).and_raise(Net::SMTPServerBusy, "boom")

      expect {
        described_class.perform_now(invitation.id)
      }.not_to raise_error

      expect(invitation.reload).to have_attributes(status: "failed")
      expect(invitation.failure_reason).to include "boom"
    end

    it 'レコードが存在しない場合は何もしない' do
      expect { described_class.perform_now(-1) }.not_to raise_error
    end
  end
end
