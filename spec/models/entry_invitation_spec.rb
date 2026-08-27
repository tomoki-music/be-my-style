require 'rails_helper'

RSpec.describe EntryInvitation do
  describe '#within_resend_window?' do
    let(:invitation) { FactoryBot.build(:entry_invitation, sent_at: sent_at) }

    context 'sent_atが24時間以内' do
      let(:sent_at) { 1.hour.ago }

      it 'trueを返す' do
        expect(invitation.within_resend_window?).to be true
      end
    end

    context 'sent_atが24時間より前' do
      let(:sent_at) { 25.hours.ago }

      it 'falseを返す' do
        expect(invitation.within_resend_window?).to be false
      end
    end

    context 'sent_atがnil' do
      let(:sent_at) { nil }

      it 'falseを返す' do
        expect(invitation.within_resend_window?).to be false
      end
    end
  end

  describe 'DBの一意制約' do
    it '(event, song, join_part, customer)の組み合わせは1行しか作れないこと' do
      first = FactoryBot.create(:entry_invitation)

      dup = FactoryBot.build(
        :entry_invitation,
        event: first.event, song: first.song, join_part: first.join_part, customer: first.customer
      )

      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
