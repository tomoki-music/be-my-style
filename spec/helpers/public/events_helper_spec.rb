require "rails_helper"

RSpec.describe Public::EventsHelper, type: :helper do
  describe "#youtube_card_for" do
    it "youtube_urlが空の場合はnilを返すこと" do
      song = build(:song, youtube_url: nil)

      expect(helper.youtube_card_for(song)).to be_nil
    end

    it "youtube_urlが未対応形式の場合はnilを返すこと" do
      song = build(:song, youtube_url: "https://example.com/not-youtube")

      expect(helper.youtube_card_for(song)).to be_nil
    end

    it "有効なYouTube URLの場合はサムネイル・タイトル・アーティスト名を含むデータを返すこと" do
      song = build(:song, song_name: "丸の内サディスティック", artist_name: "椎名林檎",
                           youtube_url: "https://www.youtube.com/watch?v=abcdefghijk")

      card = helper.youtube_card_for(song)

      expect(card.thumbnail_url).to eq("https://img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      expect(card.video_url).to eq("https://www.youtube.com/watch?v=abcdefghijk")
      expect(card.title).to eq("丸の内サディスティック")
      expect(card.author_name).to eq("椎名林檎")
    end

    it "アーティスト名が未設定でもnilを返さないこと" do
      song = build(:song, song_name: "曲名のみ", artist_name: nil,
                           youtube_url: "https://youtu.be/abcdefghijk")

      card = helper.youtube_card_for(song)

      expect(card.title).to eq("曲名のみ")
      expect(card.author_name).to be_nil
    end
  end

  describe "_youtube_card partial" do
    it "カードが存在する場合はサムネイル・タイトル・外部リンク属性を出力すること" do
      song = build(:song, song_name: "<script>alert(1)</script>", artist_name: "テスト",
                           youtube_url: "https://youtu.be/abcdefghijk")
      card = helper.youtube_card_for(song)

      html = render partial: "public/events/youtube_card", locals: { card: card }

      expect(html).to include("img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      expect(html).to include("target='_blank'")
      expect(html).to include("rel='noopener noreferrer'")
      expect(html).not_to include("<script>alert(1)</script>")
      expect(html).to include("&lt;script&gt;")
    end

    it "cardがnilの場合は何も出力しないこと" do
      html = render partial: "public/events/youtube_card", locals: { card: nil }

      expect(html.strip).to eq("")
    end
  end

  describe "#normalized_join_parts_for_column" do
    let(:event) { create(:event, :event_with_songs) }
    let(:song) { create(:song, event: event) }

    before do
      create(:join_part, song: song, join_part_name: "Vocal")
      create(:join_part, song: song, join_part_name: "ボーカル") # 旧表記
      create(:join_part, song: song, join_part_name: "Cho")      # 正規化不能
      create(:join_part, song: song, join_part_name: "Other")
      song.reload
    end

    it "旧表記も正規化して同じ固定列へ寄せる(複数件を配列で返す)" do
      names = helper.normalized_join_parts_for_column(song, "Vocal").map(&:join_part_name)
      expect(names).to contain_exactly("Vocal", "ボーカル")
    end

    it "正規化できない値はどの固定列にも出さない" do
      all_columns = JoinPart::NAME_OPTIONS.flat_map { |c| helper.normalized_join_parts_for_column(song, c) }
      expect(all_columns.map(&:join_part_name)).not_to include("Cho")
    end

    it "Other列はOtherのJoinPartを返す" do
      expect(helper.normalized_join_parts_for_column(song, "Other").map(&:join_part_name)).to eq(["Other"])
    end
  end

  describe "#experienced_customers_for" do
    let(:master) { create(:song_master) }
    let(:event) { create(:event, :event_with_songs) }
    let(:song) { create(:song, event: event).tap { |s| s.update_column(:song_master_id, master.id) } }
    let(:experienced) { create(:customer, name: "経験者") }
    let(:other_customer) { create(:customer, name: "別パート経験者") }

    it "対象キーが存在する場合はCustomer配列をそのまま返す" do
      assign(:experienced_customers_by_song_part, { [master.id, "Vocal"] => [experienced] })

      expect(helper.experienced_customers_for(song, "Vocal")).to eq([experienced])
    end

    it "経験者ハッシュが空なら空配列を返す" do
      assign(:experienced_customers_by_song_part, {})

      result = helper.experienced_customers_for(song, "Vocal")
      expect(result).to eq([])
      expect(result).to be_a(Array)
    end

    # 本番障害(PR #163)の再現: 別の曲・パートには経験者がいるため
    # ExperiencedCustomersQuery#call はデフォルト値の無い素のHashを返し、
    # 経験者のいない対象パートのキーでは nil が返っていた。
    it "別キーは存在するが対象キーが無い場合は空配列を返す(nilを返さない)" do
      assign(:experienced_customers_by_song_part, { [master.id, "Guitar"] => [other_customer] })

      result = helper.experienced_customers_for(song, "Vocal")
      expect(result).to eq([])
      expect(result).to be_a(Array)
    end

    it "@experienced_customers_by_song_part が未設定(nil)でも空配列を返す" do
      result = helper.experienced_customers_for(song, "Vocal")
      expect(result).to eq([])
      expect(result).to be_a(Array)
    end

    it "song_master_id が無い曲は空配列を返す" do
      no_master_song = build(:song, song_master_id: nil)
      assign(:experienced_customers_by_song_part, { [master.id, "Vocal"] => [experienced] })

      expect(helper.experienced_customers_for(no_master_song, "Vocal")).to eq([])
    end

    it "正規化できないパート名は空配列を返す" do
      assign(:experienced_customers_by_song_part, { [master.id, "Vocal"] => [experienced] })

      expect(helper.experienced_customers_for(song, "Cho")).to eq([])
    end
  end

  describe "#experienced_customers_for_display" do
    let(:master) { create(:song_master) }
    let(:event) { create(:event, :event_with_songs) }
    let(:song) { create(:song, event: event).tap { |s| s.update_column(:song_master_id, master.id) } }
    let(:experienced_a) { create(:customer, name: "経験Ａ") }
    let(:experienced_b) { create(:customer, name: "経験Ｂ") }

    before do
      assign(:experienced_customers_by_song_part, { [master.id, "Vocal"] => [experienced_a, experienced_b] })
    end

    it "exclude_customer_ids を Customer ID で差し引く" do
      result = helper.experienced_customers_for_display(song, "Vocal", exclude_customer_ids: [experienced_a.id])
      expect(result).to eq([experienced_b])
    end

    it "exclude が空なら基礎集合をそのまま返す" do
      result = helper.experienced_customers_for_display(song, "Vocal")
      expect(result).to contain_exactly(experienced_a, experienced_b)
    end

    # 本番障害(PR #163)の再現条件そのもの:
    # 経験者ハッシュには別の曲・パートのキーだけが存在し、対象キーは存在しない。
    # かつ exclude_customer_ids(現参加者)が1件以上ある。
    it "対象キーが無く exclude_customer_ids が非空でも例外にならず空配列を返す" do
      assign(:experienced_customers_by_song_part, { [master.id, "Guitar"] => [experienced_a] })

      result = nil
      expect {
        result = helper.experienced_customers_for_display(song, "Vocal", exclude_customer_ids: [experienced_b.id])
      }.not_to raise_error
      expect(result).to eq([])
      expect(result).to be_a(Array)
    end
  end

  describe "#entry_invitation_candidate_state" do
    let(:community) { create(:community) }
    let(:owner) { create(:customer) }
    let(:current_event) do
      create(:event, :event_with_songs, community: community, customer: owner,
             event_start_time: 2.days.from_now, event_end_time: 3.days.from_now)
    end
    let(:song) { create(:song, event: current_event) }
    let(:join_part) { create(:join_part, song: song, join_part_name: "Vocal") }
    let(:candidate) { create(:customer, name: "候補太郎") }

    before do
      join_part
      song.reload
      assign(:event, current_event)
      assign(:entry_invitations_by_key, {})
    end

    it "invitable: checkbox有効・バッジ無し" do
      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:invitable)
      expect(state.checkbox_enabled).to be true
      expect(state.badge).to be_nil
    end

    it "recently_invited: 24時間以内の依頼済みは checkbox無効・バッジ「依頼済み」" do
      invitation = EntryInvitation.new(sent_at: 1.hour.ago)
      assign(:entry_invitations_by_key, { [song.id, join_part.id, candidate.id] => invitation })

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:recently_invited)
      expect(state.checkbox_enabled).to be false
      expect(state.badge).to eq("依頼済み")
    end

    it "invited_resendable: 24時間経過後は checkbox有効・バッジ「再依頼可」" do
      invitation = EntryInvitation.new(sent_at: 2.days.ago)
      assign(:entry_invitations_by_key, { [song.id, join_part.id, candidate.id] => invitation })

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:invited_resendable)
      expect(state.checkbox_enabled).to be true
      expect(state.badge).to eq("再依頼可")
    end

    it "募集終了(現役参加者あり)のパートでも経験者は invitable: checkbox有効・バッジ無し" do
      create(:join_part_customer, join_part: join_part, customer: create(:customer))
      song.reload

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:invitable)
      expect(state.checkbox_enabled).to be true
      expect(state.badge).to be_nil
    end

    it "募集終了パートでも 24時間以内の依頼済みは checkbox無効・バッジ「依頼済み」" do
      create(:join_part_customer, join_part: join_part, customer: create(:customer))
      song.reload
      assign(:entry_invitations_by_key,
             { [song.id, join_part.id, candidate.id] => EntryInvitation.new(sent_at: 1.hour.ago) })

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:recently_invited)
      expect(state.checkbox_enabled).to be false
      expect(state.badge).to eq("依頼済み")
    end

    it "募集終了パートでも 24時間経過後は checkbox有効・バッジ「再依頼可」" do
      create(:join_part_customer, join_part: join_part, customer: create(:customer))
      song.reload
      assign(:entry_invitations_by_key,
             { [song.id, join_part.id, candidate.id] => EntryInvitation.new(sent_at: 2.days.ago) })

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:invited_resendable)
      expect(state.checkbox_enabled).to be true
      expect(state.badge).to eq("再依頼可")
    end

    it "募集終了パートでもエントリー済み(現在参加者)は checkbox無効・バッジ「エントリー済み」" do
      create(:join_part_customer, join_part: join_part, customer: create(:customer))
      song.reload

      state = helper.entry_invitation_candidate_state(song, join_part, candidate, current_member_ids: [candidate.id])
      expect(state.key).to eq(:already_entered)
      expect(state.checkbox_enabled).to be false
      expect(state.badge).to eq("エントリー済み")
    end

    it "募集状態を理由に badge「募集終了」を返さない" do
      create(:join_part_customer, join_part: join_part, customer: create(:customer))
      song.reload

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.badge).not_to eq("募集終了")
    end

    it "event_ended: 終了イベントは checkbox無効・バッジ「開催終了」" do
      allow(current_event).to receive(:ended?).and_return(true)

      state = helper.entry_invitation_candidate_state(song, join_part, candidate)
      expect(state.key).to eq(:event_ended)
      expect(state.checkbox_enabled).to be false
      expect(state.badge).to eq("開催終了")
    end

    it "already_entered: 現在参加者は最優先で checkbox無し・バッジ「エントリー済み」" do
      invitation = EntryInvitation.new(sent_at: 1.hour.ago)
      assign(:entry_invitations_by_key, { [song.id, join_part.id, candidate.id] => invitation })

      state = helper.entry_invitation_candidate_state(song, join_part, candidate, current_member_ids: [candidate.id])
      expect(state.key).to eq(:already_entered)
      expect(state.checkbox_enabled).to be false
      expect(state.badge).to eq("エントリー済み")
    end

    it "候補ごとに entry_invitations への追加SQLを発生させない" do
      assign(:entry_invitations_by_key, {})
      sql = []
      counter = ->(*, payload) { sql << payload[:sql] if payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        5.times { helper.entry_invitation_candidate_state(song, join_part, candidate) }
      end
      expect(sql.grep(/entry_invitations/i)).to be_empty
    end
  end

  describe "#entry_invitation_has_selectable_candidate?" do
    let(:community) { create(:community) }
    let(:owner) { create(:customer) }
    let(:current_event) do
      create(:event, :event_with_songs, community: community, customer: owner,
             event_start_time: 2.days.from_now, event_end_time: 3.days.from_now)
    end
    let(:master) { create(:song_master) }
    let(:song) { create(:song, event: current_event).tap { |s| s.update_column(:song_master_id, master.id) } }
    let!(:join_part) { create(:join_part, song: song, join_part_name: "Vocal") }
    let(:experienced) { create(:customer, name: "経験花子") }

    before do
      song.reload
      assign(:event, current_event)
      assign(:entry_invitations_by_key, {})
      assign(:experienced_customers_by_song_part, { [master.id, "Vocal"] => [experienced] })
    end

    it "チェックボックスが有効な候補が1人でもいれば true" do
      expect(helper.entry_invitation_has_selectable_candidate?).to be true
    end

    it "募集終了(現役参加者あり)でも経験者が依頼可能なら true" do
      create(:join_part_customer, join_part: join_part, customer: create(:customer))
      song.reload

      expect(helper.entry_invitation_has_selectable_candidate?).to be true
    end

    it "経験者はいるが全員が24時間以内に依頼済みなら false" do
      assign(:entry_invitations_by_key,
             { [song.id, join_part.id, experienced.id] => EntryInvitation.new(sent_at: 1.hour.ago) })

      expect(helper.entry_invitation_has_selectable_candidate?).to be false
    end

    it "1人でも24時間経過後の再依頼可がいれば true" do
      assign(:entry_invitations_by_key,
             { [song.id, join_part.id, experienced.id] => EntryInvitation.new(sent_at: 2.days.ago) })

      expect(helper.entry_invitation_has_selectable_candidate?).to be true
    end

    it "候補の状態集計で追加SQLを発生させない" do
      sql = []
      counter = ->(*, payload) { sql << payload[:sql] if payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        helper.entry_invitation_has_selectable_candidate?
      end
      expect(sql.grep(/entry_invitations/i)).to be_empty
    end
  end
end
