require 'rails_helper'

RSpec.describe EntryInvitations::BatchSender do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, :customer_with_parts, name: "オーナー") }
  let(:vocalist) { FactoryBot.create(:customer, name: "ボーカル太郎") }
  let(:guitarist) { FactoryBot.create(:customer, name: "ギター花子") }

  let(:past_event) do
    FactoryBot.create(:event, :event_with_songs, community: community, customer: owner,
      event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago)
  end
  let(:current_event) do
    FactoryBot.create(:event, :event_with_songs, community: community, customer: owner,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now)
  end

  let(:past_song_a) { FactoryBot.create(:song, event: past_event, song_name: "曲A", artist_name: "アーティストA") }
  let(:current_song_a) { FactoryBot.create(:song, event: current_event, song_name: "曲A", artist_name: "アーティストA") }
  let(:past_vocal) { FactoryBot.create(:join_part, song: past_song_a, join_part_name: "Vocal") }
  let(:current_vocal) { FactoryBot.create(:join_part, song: current_song_a, join_part_name: "Vocal") }
  let(:past_guitar) { FactoryBot.create(:join_part, song: past_song_a, join_part_name: "Guitar") }
  let(:current_guitar) { FactoryBot.create(:join_part, song: current_song_a, join_part_name: "Guitar") }
  let(:past_song_b) { FactoryBot.create(:song, event: past_event, song_name: "曲B", artist_name: "アーティストB") }
  let(:current_song_b) { FactoryBot.create(:song, event: current_event, song_name: "曲B", artist_name: "アーティストB") }
  let(:past_vocal_b) { FactoryBot.create(:join_part, song: past_song_b, join_part_name: "Vocal") }
  let(:current_vocal_b) { FactoryBot.create(:join_part, song: current_song_b, join_part_name: "Vocal") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    current_vocal
    current_guitar
    current_vocal_b
    FactoryBot.create(:join_part_customer, join_part: past_vocal, customer: vocalist)
    FactoryBot.create(:join_part_customer, join_part: past_guitar, customer: guitarist)
    FactoryBot.create(:join_part_customer, join_part: past_vocal_b, customer: vocalist)
  end

  def target(song, part, customer)
    "#{song.id}:#{part.id}:#{customer.id}"
  end

  def call(raw_targets, sender: owner, now: Time.current)
    described_class.call(event: current_event, sender: sender, raw_targets: raw_targets, now: now)
  end

  describe "グループ化と委譲" do
    it "targets を曲・パート単位へグループ化し、各グループで既存 Sender を呼ぶ" do
      expect(EntryInvitations::Sender).to receive(:call)
        .with(hash_including(song: current_song_a, join_part: current_vocal, requested_customer_ids: [vocalist.id]))
        .and_call_original
      expect(EntryInvitations::Sender).to receive(:call)
        .with(hash_including(song: current_song_a, join_part: current_guitar, requested_customer_ids: [guitarist.id]))
        .and_call_original

      call([target(current_song_a, current_vocal, vocalist), target(current_song_a, current_guitar, guitarist)])
    end

    it "重複 target を除去してから処理する" do
      t = target(current_song_a, current_vocal, vocalist)

      result = nil
      expect { result = call([t, t, t]) }.to change(EntryInvitation, :count).by(1)
      expect(result.queued_count).to eq 1
    end

    it "queued 件数を集約する（複数グループ合計）" do
      result = call([
        target(current_song_a, current_vocal, vocalist),
        target(current_song_a, current_guitar, guitarist),
        target(current_song_b, current_vocal_b, vocalist)
      ])

      expect(result).to be_success
      expect(result.queued_count).to eq 3
    end
  end

  describe "不正・対象外 target" do
    it "不正な形式は安全に無視する" do
      result = call(["abc", "1:2", nil].compact + [target(current_song_a, current_vocal, vocalist)])

      expect(result).to be_success
      expect(result.queued_count).to eq 1
    end

    it "改ざん target（無関係な人）は skipped に集計し、送信しない" do
      stranger = FactoryBot.create(:customer, name: "無関係")

      result = call([
        target(current_song_a, current_vocal, vocalist),
        target(current_song_a, current_vocal, stranger)
      ])

      expect(result.queued_count).to eq 1
      expect(result.skipped_count).to eq 1
    end

    it "有効な対象が 0 件なら error を返す" do
      result = call(["1:2:3", "abc"])

      expect(result).not_to be_success
      expect(result.error).to be_present
    end

    it "配列以外・nil を渡しても例外を起こさず error を返す" do
      expect { call(nil) }.not_to raise_error
      expect(call(nil)).not_to be_success
      expect(call("garbage")).not_to be_success
    end
  end

  describe "再送防止・部分成功" do
    it "24時間以内に送信済みの対象は recently_sent に集計し、他は送信する" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song_a, join_part: current_vocal,
        customer: vocalist, requested_by_customer: owner, sent_at: 1.hour.ago)

      result = call([
        target(current_song_a, current_vocal, vocalist),
        target(current_song_b, current_vocal_b, vocalist)
      ])

      expect(result.queued_count).to eq 1
      expect(result.recently_sent_count).to eq 1
    end

    it "既に成功したグループを再送しない（部分失敗でも二重送信しない）" do
      # 曲A Vocal は募集終了させ、グループ単位で送信不可にする
      FactoryBot.create(:join_part_customer, join_part: current_vocal, customer: FactoryBot.create(:customer))

      result = nil
      expect {
        result = call([
          target(current_song_a, current_vocal, vocalist),
          target(current_song_b, current_vocal_b, vocalist)
        ])
      }.to change { EntryInvitation.where(song_id: current_song_b.id).count }.by(1)

      expect(EntryInvitation.where(song_id: current_song_a.id)).to be_empty
      expect(result.queued_count).to eq 1
      expect(result.skipped_count).to be >= 1
    end
  end

  describe "権限・イベント状態" do
    it "送信権限のないユーザーは error を返し、何も送らない" do
      stranger = FactoryBot.create(:customer)

      result = call([target(current_song_a, current_vocal, vocalist)], sender: stranger)

      expect(result).not_to be_success
      expect(EntryInvitation.count).to eq 0
    end

    it "終了済みイベントは error を返す" do
      result = call([target(current_song_a, current_vocal, vocalist)], now: 5.days.from_now)

      expect(result).not_to be_success
      expect(result.error).to include "終了"
    end

    it "上限超過は error を返す" do
      targets = Array.new(EntryInvitations::TargetParser::MAX_TARGETS + 1) { |i| "#{current_song_a.id}:#{current_vocal.id}:#{i + 1}" }

      result = call(targets)

      expect(result).not_to be_success
      expect(result.error).to include EntryInvitations::TargetParser::MAX_TARGETS.to_s
    end
  end

  describe "Job / Mailer 委譲" do
    it "曲・パート単位で個別に Job が積まれる" do
      expect {
        call([
          target(current_song_a, current_vocal, vocalist),
          target(current_song_b, current_vocal_b, vocalist)
        ])
      }.to have_enqueued_job(SendEntryInvitationJob).twice
    end
  end
end
