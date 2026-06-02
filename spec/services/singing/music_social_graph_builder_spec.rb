require "rails_helper"

RSpec.describe Singing::MusicSocialGraphBuilder do
  def create_join_part
    event = build(:event)
    song = build(:song, event: event)
    event.songs = [song]
    event.save!
    song.save!
    create(:join_part, song: song)
  end

  def completed_diagnosis(customer, attrs = {})
    create(
      :singing_diagnosis,
      :completed,
      {
        customer:         customer,
        overall_score:    75,
        pitch_score:      72,
        rhythm_score:     74,
        expression_score: 73,
        created_at:       Time.current
      }.merge(attrs)
    )
  end

  describe ".call" do
    subject(:result) { described_class.call(customer: customer) }

    let(:customer) { create(:customer, domain_name: "singing") }

    context "nil customer の場合" do
      it "例外を発生させない" do
        expect { described_class.call(customer: nil) }.not_to raise_error
      end

      it "MusicSocialGraph を返す" do
        graph = described_class.call(customer: nil)

        expect(graph).to be_a(described_class::MusicSocialGraph)
      end

      it "すべてのカウントが 0" do
        graph = described_class.call(customer: nil)

        expect(graph.connected_members_count).to eq(0)
        expect(graph.cheer_connections_count).to eq(0)
        expect(graph.growth_type_connections_count).to eq(0)
        expect(graph.mission_connections_count).to eq(0)
        expect(graph.event_connections_count).to eq(0)
      end

      it "graph_message が存在する" do
        graph = described_class.call(customer: nil)

        expect(graph.graph_message).to be_present
      end
    end

    context "診断履歴なし（自分も他者も 0 件）" do
      it "MusicSocialGraph を返す" do
        expect(result).to be_a(described_class::MusicSocialGraph)
      end

      it "connected_members_count が 0" do
        expect(result.connected_members_count).to eq(0)
      end

      it "graph_message が存在する" do
        expect(result.graph_message).to be_present
      end
    end

    context "自分自身は除外される" do
      before do
        completed_diagnosis(customer, created_at: 5.days.ago)
      end

      it "connected_members_count に自分は含まれない" do
        expect(result.connected_members_count).to eq(0)
      end
    end

    context "Cheer 関係の集計" do
      let(:other_a) { create(:customer, domain_name: "singing") }
      let(:other_b) { create(:customer, domain_name: "singing") }

      before do
        create(:singing_cheer_reaction, customer: customer, target_customer: other_a)
        create(:singing_cheer_reaction, customer: other_b, target_customer: customer)
      end

      it "自分が応援したユーザーを cheer_connections_count に含む" do
        expect(result.cheer_connections_count).to be >= 1
      end

      it "自分を応援してくれたユーザーも cheer_connections_count に含む" do
        expect(result.cheer_connections_count).to eq(2)
      end

      it "cheer 接点が connected_members_count に反映される" do
        expect(result.connected_members_count).to be >= 2
      end
    end

    context "Cheer 重複ユーザー（双方向応援）は 1 としてカウントされる" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        create(:singing_cheer_reaction, customer: customer, target_customer: other)
        create(:singing_cheer_reaction, customer: other,    target_customer: customer)
      end

      it "cheer_connections_count が 1" do
        expect(result.cheer_connections_count).to eq(1)
      end
    end

    context "GrowthType 一致の集計" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        completed_diagnosis(customer, created_at: 5.days.ago)
        completed_diagnosis(other,    created_at: 5.days.ago)
      end

      it "同じ GrowthType のユーザーを growth_type_connections_count に含む" do
        expect(result.growth_type_connections_count).to be >= 1
      end

      it "growth_type 接点が connected_members_count に反映される" do
        expect(result.connected_members_count).to be >= 1
      end
    end

    context "Mission 一致の集計" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        # expression スコアが伸びている = :expression mission
        completed_diagnosis(customer, expression_score: 55, pitch_score: 70, rhythm_score: 70, overall_score: 70, created_at: 3.days.ago)
        completed_diagnosis(customer, expression_score: 75, pitch_score: 71, rhythm_score: 71, overall_score: 75, created_at: 1.day.ago)
        completed_diagnosis(other,    expression_score: 55, pitch_score: 70, rhythm_score: 70, overall_score: 70, created_at: 3.days.ago)
        completed_diagnosis(other,    expression_score: 75, pitch_score: 71, rhythm_score: 71, overall_score: 75, created_at: 1.day.ago)
      end

      it "同じ Mission のユーザーを mission_connections_count に含む" do
        expect(result.mission_connections_count).to be >= 1
      end

      it "mission 接点が connected_members_count に反映される" do
        expect(result.connected_members_count).to be >= 1
      end
    end

    context "Event 接点の集計" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        join_part = create_join_part
        create(:join_part_customer, customer: customer, join_part: join_part)
        create(:join_part_customer, customer: other,    join_part: join_part)
      end

      it "同じイベントに参加したユーザーを event_connections_count に含む" do
        expect(result.event_connections_count).to eq(1)
      end

      it "event 接点が connected_members_count に反映される" do
        expect(result.connected_members_count).to be >= 1
      end
    end

    context "connected_members_count が重複排除される" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        join_part = create_join_part
        # other が cheer でも event でも重複する
        create(:singing_cheer_reaction, customer: customer, target_customer: other)
        create(:join_part_customer, customer: customer, join_part: join_part)
        create(:join_part_customer, customer: other,    join_part: join_part)
      end

      it "同じユーザーが複数経路でつながっていても 1 としてカウントされる" do
        expect(result.connected_members_count).to eq(1)
      end

      it "cheer と event は別々にカウントされる" do
        expect(result.cheer_connections_count).to eq(1)
        expect(result.event_connections_count).to eq(1)
      end
    end

    context "graph_message の 3 段階分岐" do
      it "count >= 20 のとき輪が広がるメッセージ" do
        builder = described_class.new(customer: customer)
        expect(builder.send(:message_for, 20)).to include("広がっています")
      end

      it "count >= 5 のとき仲間の輪メッセージ" do
        builder = described_class.new(customer: customer)
        expect(builder.send(:message_for, 5)).to include("生まれています")
      end

      it "count < 5 のとき育っていくメッセージ" do
        builder = described_class.new(customer: customer)
        expect(builder.send(:message_for, 4)).to include("育っていきます")
      end

      it "count = 0 のとき育っていくメッセージ" do
        expect(result.graph_message).to include("育っていきます")
      end
    end

    context "全フィールドが揃っている" do
      it "MusicSocialGraph の全フィールドが存在する" do
        expect(result.connected_members_count).to be_a(Integer)
        expect(result.cheer_connections_count).to be_a(Integer)
        expect(result.growth_type_connections_count).to be_a(Integer)
        expect(result.mission_connections_count).to be_a(Integer)
        expect(result.event_connections_count).to be_a(Integer)
        expect(result.graph_message).to be_present
      end
    end
  end
end
