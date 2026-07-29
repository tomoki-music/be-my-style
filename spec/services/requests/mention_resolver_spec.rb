require "rails_helper"

RSpec.describe Requests::MentionResolver, type: :service do
  let(:poster) { create(:customer, name: "投稿者") }
  let(:event) { create(:event, :event_with_songs) }
  let(:song) { event.songs.first }
  let(:join_part_a) { create(:join_part, song: song) }
  let(:join_part_b) { create(:join_part, song: song) }
  let(:participant_a) { create(:customer, name: "参加太郎") }
  let(:participant_b) { create(:customer, name: "参加花子") }

  before do
    create(:join_part_customer, join_part: join_part_a, customer: poster)
    create(:join_part_customer, join_part: join_part_a, customer: participant_a)
    create(:join_part_customer, join_part: join_part_b, customer: participant_b)
  end

  describe "個別メンション" do
    it "本文中の[@name](customer:ID)から参加者を解決すること" do
      text = "[@参加太郎](customer:#{participant_a.id})お願いします"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(participant_a)
    end

    it "複数の個別メンションを解決し、重複を排除すること" do
      text = "[@参加太郎](customer:#{participant_a.id}) [@参加花子](customer:#{participant_b.id}) " \
             "[@参加太郎](customer:#{participant_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(participant_a, participant_b)
    end

    it "投稿者本人を本文中でメンションしても通知対象に含まれないこと" do
      text = "[@投稿者](customer:#{poster.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "このイベントに参加していないCustomerのIDを本文へ直接書いても通知対象に含まれないこと" do
      outsider = create(:customer, name: "未参加者")
      text = "[@未参加者](customer:#{outsider.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "退会済み参加者は通知対象に含まれないこと" do
      participant_a.update!(is_deleted: true)
      text = "[@参加太郎](customer:#{participant_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "存在しないCustomer IDを本文へ書いても例外にならず、通知対象に含まれないこと" do
      text = "[@誰か](customer:999999)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "メンションを含まない本文では空配列を返すこと" do
      result = described_class.call(request_text: "オリジナル曲をお願いします", event: event, poster: poster)
      expect(result).to eq []
    end
  end

  describe "@ALL" do
    it "[@ALL](customer:all)を含む場合、投稿者を除く現在の参加者全員を返すこと" do
      text = "[@ALL](customer:all) 見てください"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(participant_a, participant_b)
    end

    it "投稿者自身は@ALLの対象に含まれないこと" do
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).not_to include(poster)
    end

    it "退会済み参加者は@ALLの対象に含まれないこと" do
      participant_a.update!(is_deleted: true)
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(participant_b)
    end

    it "イベントオーナーでも参加登録していなければ@ALLの対象に含まれないこと" do
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).not_to include(event.customer)
    end

    it "@ALLと個別メンションが同時に書かれても対象は重複しないこと" do
      text = "[@ALL](customer:all) [@参加太郎](customer:#{participant_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result.map(&:id).tally.values).to all(eq(1))
      expect(result).to contain_exactly(participant_a, participant_b)
    end
  end
end
