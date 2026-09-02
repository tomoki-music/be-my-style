require 'rails_helper'

RSpec.describe "Public::PerformanceRankings", type: :request do
  let(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:community) { create(:community, domain: music_domain, name: "みんなのコミュニティ") }
  let(:other_community) { create(:community, domain: music_domain, name: "べつのコミュニティ") }
  let(:viewer) { create(:customer, name: "閲覧者") }

  def ended_event(in_community: nil, start_time: 20.days.ago, name: nil)
    create(
      :event, :event_with_songs,
      community: in_community || community,
      event_name: name || "イベント#{start_time.to_i}",
      event_start_time: start_time,
      event_end_time: start_time + 2.hours,
      event_entry_deadline: start_time - 1.day
    )
  end

  def perform!(event, customer:, song_name: "曲", artist_name: "A", part: "Vocal", song: nil)
    song ||= create(:song, event: event, song_name: song_name, artist_name: artist_name)
    join_part = create(:join_part, song: song, join_part_name: part)
    create(:join_part_customer, join_part: join_part, customer: customer)
    song
  end

  describe "認証" do
    it "未ログインならログイン画面へリダイレクトすること" do
      get public_performance_rankings_path
      expect(response).to redirect_to(new_customer_session_path)
    end

    it "ログイン済みなら200で閲覧できること" do
      sign_in viewer
      get public_performance_rankings_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "表示" do
    before { sign_in viewer }

    it "両方のランキング基準を表示でき、行にプロフィールへのリンクを含むこと" do
      star = create(:customer, name: "スター奏者")
      event = ended_event
      perform!(event, customer: star, song_name: "曲1", part: "Vocal")
      perform!(event, customer: star, song_name: "曲2", part: "Guitar")

      %w[performances events].each do |kind|
        get public_performance_rankings_path, params: { kind: kind }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("スター奏者")
        expect(response.body).to include(public_customer_path(star))
      end
    end

    it "選択中の基準に応じてラベルが切り替わること" do
      get public_performance_rankings_path, params: { kind: "performances" }
      expect(Nokogiri::HTML(response.body).at_css('select#kind option[selected]')['value']).to eq "performances"

      get public_performance_rankings_path, params: { kind: "events" }
      expect(Nokogiri::HTML(response.body).at_css('select#kind option[selected]')['value']).to eq "events"
    end

    it "GETパラメータの選択状態がフォームに保持されること" do
      get public_performance_rankings_path, params: {
        kind: "events", scope: "community", community_id: community.id,
        period: "custom", start_on: "2026-01-01", end_on: "2026-03-31"
      }
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('select#kind option[selected]')['value']).to eq "events"
      expect(doc.at_css('select#scope option[selected]')['value']).to eq "community"
      expect(doc.at_css('select#community_id option[selected]')['value']).to eq community.id.to_s
      expect(doc.at_css('select#period option[selected]')['value']).to eq "custom"
      expect(doc.at_css('input#start_on')['value']).to eq "2026-01-01"
    end

    it "データ0件のときは温かい空状態を表示すること" do
      get public_performance_rankings_path
      expect(response.body).to include("まだ演奏実績がありません")
    end

    it "上位3名には控えめな特別クラスが付き、一覧はレスポンシブなカード構造を持つこと" do
      event = ended_event
      4.times do |i|
        customer = create(:customer, name: "P#{i}")
        (4 - i).times { |j| perform!(event, customer: customer, song_name: "s#{i}-#{j}") }
      end

      get public_performance_rankings_path
      doc = Nokogiri::HTML(response.body)
      expect(doc.css(".performance-ranking__list .performance-ranking__item").size).to eq 4
      expect(doc.css(".performance-ranking__item .performance-ranking__main").size).to eq 4
      expect(doc.css(".performance-ranking__item--top-1").size).to eq 1
      expect(doc.css(".performance-ranking__item--top-3").size).to eq 1
      expect(doc.at_css(".performance-ranking__item--top-4")).to be_nil
    end

    it "説明文が確定文言であること" do
      get public_performance_rankings_path
      expect(response.body).to include("イベントで活躍しているメンバーをご紹介")
      expect(response.body).to include("気になるメンバーの詳細を開くと")
    end

    it "開始日が終了日より後のときはエラーメッセージを表示し500にならないこと" do
      get public_performance_rankings_path, params: { period: "custom", start_on: "2026-09-30", end_on: "2026-09-01" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("開始日は終了日より前")
    end

    it "不正な community_id / 日付でも500にならないこと" do
      get public_performance_rankings_path, params: {
        scope: "community", community_id: "not-a-number", period: "custom", start_on: "2026-02-30", end_on: "???"
      }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "展開詳細(インライン)" do
    before { sign_in viewer }

    it "各ユーザー行に一意な collapse ID の詳細と開閉ボタンがあること" do
      event = ended_event(name: "春の発表会")
      a = create(:customer, name: "詳細Aさん")
      b = create(:customer, name: "詳細Bさん")
      perform!(event, customer: a, song_name: "マリーゴールド", artist_name: "あいみょん", part: "Vocal")
      perform!(event, customer: b, song_name: "丸の内サディスティック", artist_name: "椎名林檎", part: "Guitar")

      get public_performance_rankings_path
      doc = Nokogiri::HTML(response.body)

      detail_ids = doc.css(".performance-ranking__detail").map { |n| n["id"] }
      expect(detail_ids).to match_array(detail_ids.uniq)
      expect(detail_ids).to contain_exactly(
        "performance-ranking-detail-#{a.id}",
        "performance-ranking-detail-#{b.id}"
      )

      toggle = doc.at_css(".performance-ranking__detail-toggle")
      expect(toggle["aria-expanded"]).to eq "false"
      expect(toggle["aria-controls"]).to start_with("performance-ranking-detail-")
      expect(toggle["data-target"]).to eq "##{toggle['aria-controls']}"
    end

    it "詳細に参加イベント名・イベント詳細リンク・演奏楽曲名・担当パートを表示すること" do
      event = ended_event(name: "夏フェス2026")
      alice = create(:customer, name: "アリスさん")
      perform!(event, customer: alice, song_name: "マリーゴールド", artist_name: "あいみょん", part: "Vocal")

      get public_performance_rankings_path
      body = response.body
      expect(body).to include("夏フェス2026")
      expect(body).to include(public_event_path(event))
      expect(body).to include("マリーゴールド")
      expect(body).to include("Vocal：1回")
    end

    it "一覧と展開詳細に同じ期間・範囲条件が適用されること" do
      alice = create(:customer, name: "期間テストさん")
      in_range = ended_event(start_time: Time.zone.local(2026, 3, 10, 12), name: "対象イベント")
      out_range = ended_event(start_time: Time.zone.local(2025, 1, 10, 12), name: "対象外イベント")
      perform!(in_range, customer: alice, song_name: "対象曲")
      perform!(out_range, customer: alice, song_name: "対象外曲")

      get public_performance_rankings_path, params: { period: "custom", start_on: "2026-03-01", end_on: "2026-03-31" }
      body = response.body
      expect(body).to include("対象イベント")
      expect(body).to include("対象曲")
      expect(body).not_to include("対象外イベント")
      expect(body).not_to include("対象外曲")
    end
  end

  describe "集計範囲と権限" do
    before { sign_in viewer }

    it "コミュニティ内指定でも他コミュニティの演奏実績が混ざらないこと" do
      here = create(:customer, name: "こっちの人")
      there = create(:customer, name: "あっちの人")
      perform!(ended_event(in_community: community), customer: here, song_name: "こっち曲")
      perform!(ended_event(in_community: other_community), customer: there, song_name: "あっち曲")

      get public_performance_rankings_path, params: { scope: "community", community_id: community.id }
      expect(response.body).to include("こっちの人")
      expect(response.body).not_to include("あっちの人")
    end

    it "musicドメイン以外のコミュニティ名・そこだけの参加者が全体ランキングから漏れないこと" do
      biz_community = create(:community, domain: business_domain, name: "ビジネス秘密結社")
      biz_only = create(:customer, name: "ビジネス専属")
      perform!(ended_event(in_community: biz_community), customer: biz_only, song_name: "業務曲")

      get public_performance_rankings_path
      expect(response.body).not_to include("ビジネス秘密結社")
      expect(response.body).not_to include("ビジネス専属")
    end

    it "退会済みユーザーはランキングにも詳細にも出ないこと" do
      withdrawn = create(:customer, name: "退会した人", is_deleted: true)
      perform!(ended_event, customer: withdrawn, song_name: "退会者曲")

      get public_performance_rankings_path
      expect(response.body).not_to include("退会した人")
    end
  end

  describe "クエリ効率" do
    before { sign_in viewer }

    it "ランキング行が増えても発行クエリ数がほぼ一定であること(N+1がない)" do
      create_list(:customer, 2).each_with_index do |c, i|
        perform!(ended_event(start_time: (30 - i).days.ago), customer: c, song_name: "初期#{i}")
      end

      baseline = count_queries { get public_performance_rankings_path }

      create_list(:customer, 8).each_with_index do |c, i|
        event = ended_event(start_time: (20 - i).days.ago)
        perform!(event, customer: c, song_name: "追加#{i}-1", part: "Vocal")
        perform!(event, customer: c, song_name: "追加#{i}-2", part: "Guitar")
      end

      after_growth = count_queries { get public_performance_rankings_path }

      # 行数が 2 → 10、詳細(イベント/楽曲/パート)が増えても行ごとの追加クエリが無いこと。
      expect(after_growth).to be <= baseline + 3
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(_name, _start, _finish, _id, payload) do
      count += 1 unless payload[:name].to_s =~ /SCHEMA|TRANSACTION/ || payload[:sql] =~ /^\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
