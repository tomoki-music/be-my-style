require 'rails_helper'

RSpec.describe EntryInvitations::Sender do
  include ActiveJob::TestHelper

  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:experienced_customer) { FactoryBot.create(:customer, name: "経験太郎") }

  let(:past_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago
    )
  end
  let(:current_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
  end

  let(:past_song) { FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:current_song) { FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:past_vocal_part) { FactoryBot.create(:join_part, song: past_song, join_part_name: "Vocal") }
  let(:current_vocal_part) { FactoryBot.create(:join_part, song: current_song, join_part_name: "Vocal") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    current_vocal_part
    # 経験太郎: 終了済みイベントの同一曲・同一パートに実績あり
    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)
  end

  def call(customer_ids:, song: current_song, join_part: current_vocal_part, sender: owner, now: Time.current)
    described_class.call(
      event: current_event, song: song, join_part: join_part,
      sender: sender, requested_customer_ids: customer_ids, now: now
    )
  end

  describe '正常系' do
    it '選択した経験者だけにエントリー依頼を送る（履歴保存＋ジョブ投入）' do
      other_experienced = FactoryBot.create(:customer, name: "選ばれない人")
      FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: other_experienced)

      result = nil
      expect {
        result = call(customer_ids: [experienced_customer.id])
      }.to change(EntryInvitation, :count).by(1)
        .and have_enqueued_job(SendEntryInvitationJob)

      expect(result.queued).to contain_exactly(experienced_customer)
      invitation = EntryInvitation.last
      expect(invitation).to have_attributes(
        event_id: current_event.id, song_id: current_song.id, join_part_id: current_vocal_part.id,
        customer_id: experienced_customer.id, requested_by_customer_id: owner.id, status: "pending"
      )
      expect(invitation.sent_at).to be_present
    end

    it '選択していない経験者には送らない' do
      not_selected = FactoryBot.create(:customer, name: "非選択経験者")
      FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: not_selected)

      call(customer_ids: [experienced_customer.id])

      expect(EntryInvitation.where(customer_id: not_selected.id)).to be_empty
    end
  end

  describe '送信対象の再検証' do
    it '同一曲でも別パートの経験者には送信できない' do
      other_part_customer = FactoryBot.create(:customer, name: "ギター経験者")
      past_guitar_part = FactoryBot.create(:join_part, song: past_song, join_part_name: "Guitar")
      FactoryBot.create(:join_part_customer, join_part: past_guitar_part, customer: other_part_customer)
      FactoryBot.create(:join_part, song: current_song, join_part_name: "Guitar")

      result = call(customer_ids: [other_part_customer.id], join_part: current_vocal_part)

      expect(result.queued).to be_empty
      expect(result.skipped.first[:reason]).to eq :not_experienced
    end

    it '別のSongMaster（別の曲）の経験者には送信できない' do
      other_song_customer = FactoryBot.create(:customer, name: "別曲経験者")
      other_past_song = FactoryBot.create(:song, event: past_event, song_name: "別の曲", artist_name: "別アーティスト")
      other_past_part = FactoryBot.create(:join_part, song: other_past_song, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: other_past_part, customer: other_song_customer)

      result = call(customer_ids: [other_song_customer.id])

      expect(result.queued).to be_empty
    end

    it '現在イベント自身のエントリーだけの人には送信できない' do
      self_only = FactoryBot.create(:customer, name: "当該イベントのみ")
      FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: self_only)

      result = call(customer_ids: [self_only.id])

      expect(result.queued).to be_empty
    end

    it '退会済みユーザーには送信できない' do
      withdrawn = FactoryBot.create(:customer, name: "退会者", is_deleted: true)
      FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: withdrawn)

      result = call(customer_ids: [withdrawn.id])

      expect(result.queued).to be_empty
      # 退会者はそもそも経験者クエリに載らないため not_experienced 判定でも良い
      expect(result.skipped.first[:reason]).to be_in(%i[withdrawn not_experienced])
    end

    it 'すでに該当パートへエントリー済みの人には送信できない' do
      FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: experienced_customer)

      result = call(customer_ids: [experienced_customer.id])

      expect(result.queued).to be_empty
      expect(EntryInvitation.where(customer_id: experienced_customer.id)).to be_empty
    end

    it 'receiverごとのエントリー済み判定（disqualification_reason）が :already_entered を返すこと' do
      # 本人がすでに該当パートへエントリー済み。パートの募集状態は問わない(validate_context で
      # 弾かれない)ため、個別受信者チェックの :already_entered 分岐がそのまま働く。
      FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: experienced_customer)

      result = call(customer_ids: [experienced_customer.id])

      expect(result.queued).to be_empty
      expect(result.skipped.first[:reason]).to eq :already_entered
    end

    it 'イベント開催終了後は送信できない' do
      result = call(customer_ids: [experienced_customer.id], now: 5.days.from_now)

      expect(result.success?).to be false
      expect(result.error).to include "終了"
      expect(EntryInvitation.count).to eq 0
    end

    it '募集終了済み（別の参加者あり）のパートでも経験者へは送信できる' do
      FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: FactoryBot.create(:customer))

      result = nil
      expect {
        result = call(customer_ids: [experienced_customer.id])
      }.to change(EntryInvitation, :count).by(1)
        .and have_enqueued_job(SendEntryInvitationJob)

      expect(result.success?).to be true
      expect(result.queued).to contain_exactly(experienced_customer)
    end

    it 'customer_id改ざんで無関係な人へは送信できない' do
      unrelated = FactoryBot.create(:customer, name: "無関係")

      result = call(customer_ids: [unrelated.id])

      expect(result.queued).to be_empty
      expect(result.skipped.first[:reason]).to eq :not_experienced
    end

    it 'メール通知をオフにしている経験者には送信しない' do
      experienced_customer.update!(confirm_mail: false)

      result = call(customer_ids: [experienced_customer.id])

      expect(result.queued).to be_empty
      expect(result.skipped.first[:reason]).to eq :mail_opt_out
    end
  end

  describe '連続送信防止' do
    it '24時間以内に送信済みなら再送しない' do
      FactoryBot.create(
        :entry_invitation,
        event: current_event, song: current_song, join_part: current_vocal_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 1.hour.ago
      )

      result = call(customer_ids: [experienced_customer.id])

      expect(result.queued).to be_empty
      expect(result.skipped.first[:reason]).to eq :recently_sent
    end

    it '24時間経過後は再送でき、既存行を更新する' do
      invitation = FactoryBot.create(
        :entry_invitation,
        event: current_event, song: current_song, join_part: current_vocal_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 25.hours.ago, status: :delivered
      )

      expect {
        call(customer_ids: [experienced_customer.id])
      }.not_to change(EntryInvitation, :count)

      expect(invitation.reload.status).to eq "pending"
      expect(invitation.sent_at).to be > 1.minute.ago
    end
  end

  describe '権限' do
    it '送信権限のないユーザーはerrorを返し、何も送らない' do
      stranger = FactoryBot.create(:customer)

      result = call(customer_ids: [experienced_customer.id], sender: stranger)

      expect(result.success?).to be false
      expect(EntryInvitation.count).to eq 0
    end
  end
end
