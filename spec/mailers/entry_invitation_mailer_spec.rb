require 'rails_helper'

RSpec.describe EntryInvitationMailer do
  describe '#invite' do
    let(:community) { FactoryBot.create(:community) }
    let(:recipient) { FactoryBot.create(:customer, name: "経験太郎") }
    let(:sender) { FactoryBot.create(:customer, name: "主催花子") }
    let(:event) do
      FactoryBot.create(
        :event, :event_with_songs, community: community, customer: sender,
        event_name: "春の音楽会",
        event_start_time: Time.zone.local(2026, 5, 3, 18, 0),
        event_end_time: Time.zone.local(2026, 5, 3, 21, 0),
        event_entry_deadline: Time.zone.local(2026, 5, 1, 0, 0)
      )
    end
    let(:song) { FactoryBot.create(:song, event: event, song_name: "マリーゴールド", artist_name: "あいみょん") }
    let(:join_part) { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }
    let(:invitation) do
      FactoryBot.create(
        :entry_invitation,
        event: event, song: song, join_part: join_part,
        customer: recipient, requested_by_customer: sender
      )
    end

    subject(:mail) { described_class.invite(invitation) }

    it '受信者本人のみを To に設定し、CC/BCC を使わない' do
      expect(mail.to).to eq [recipient.email]
      expect(mail.cc).to be_blank
      expect(mail.bcc).to be_blank
    end

    it '件名に曲名とパート名を含む' do
      expect(mail.subject).to eq "【BeMyStyle】「マリーゴールド」のVocalにエントリーしませんか？"
    end

    it '本文にユーザー名・イベント名・曲名・アーティスト名・パート名・開催日・イベント詳細URLを含む' do
      body = mail.body.encoded

      expect(body).to include "経験太郎"
      expect(body).to include "春の音楽会"
      expect(body).to include "マリーゴールド"
      expect(body).to include "あいみょん"
      expect(body).to include "Vocal"
      expect(body).to include "2026年05月03日"
      expect(body).to include "https://be-my-style.com/public/events/#{event.id}"
    end
  end
end
