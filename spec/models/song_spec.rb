require 'rails_helper'

RSpec.describe Song, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'バリデーションのテスト' do
    context 'songテーブルのカラムが不正' do
      it 'song_nameカラムが空欄でないこと' do
        song.song_name = ''
        expect(song.valid?).to eq false
      end
    end

    context 'chord_sheet_url' do
      it 'nilなら有効であること' do
        song.chord_sheet_url = nil
        expect(song.valid?).to eq true
      end

      it '空欄なら有効であること' do
        song.chord_sheet_url = ''
        expect(song.valid?).to eq true
      end

      it '2048文字以内なら有効であること' do
        base = 'https://example.com/'
        song.chord_sheet_url = base + ('a' * (2048 - base.length))
        expect(song.chord_sheet_url.length).to eq 2048
        expect(song.valid?).to eq true
      end

      it '2049文字なら無効であること' do
        base = 'https://example.com/'
        song.chord_sheet_url = base + ('a' * (2049 - base.length))
        expect(song.chord_sheet_url.length).to eq 2049
        expect(song.valid?).to eq false
      end

      it 'URL形式でない文字列でも、長さ以内なら有効であること' do
        song.chord_sheet_url = 'これはURLではない文字列です'
        expect(song.valid?).to eq true
      end
    end

    context 'tab_sheet_url' do
      it 'nilなら有効であること' do
        song.tab_sheet_url = nil
        expect(song.valid?).to eq true
      end

      it '空欄なら有効であること' do
        song.tab_sheet_url = ''
        expect(song.valid?).to eq true
      end

      it '2048文字以内なら有効であること' do
        base = 'https://example.com/'
        song.tab_sheet_url = base + ('a' * (2048 - base.length))
        expect(song.tab_sheet_url.length).to eq 2048
        expect(song.valid?).to eq true
      end

      it '2049文字なら無効であること' do
        base = 'https://example.com/'
        song.tab_sheet_url = base + ('a' * (2049 - base.length))
        expect(song.tab_sheet_url.length).to eq 2049
        expect(song.valid?).to eq false
      end

      it 'URL形式でない文字列でも、長さ以内なら有効であること' do
        song.tab_sheet_url = 'これはURLではない文字列です'
        expect(song.valid?).to eq true
      end
    end

    context 'musical_key' do
      it '空欄なら有効であること' do
        song.musical_key = ''
        expect(song.valid?).to eq true
      end

      it '"G"のような候補値が有効であること' do
        song.musical_key = 'G'
        expect(song.valid?).to eq true
      end

      it '"Am"のような候補値が有効であること' do
        song.musical_key = 'Am'
        expect(song.valid?).to eq true
      end

      it '候補外の自由入力"原曲:G→演奏:A"も有効であること' do
        song.musical_key = '原曲:G→演奏:A'
        expect(song.valid?).to eq true
      end

      it '100文字なら有効であること' do
        song.musical_key = 'a' * 100
        expect(song.valid?).to eq true
      end

      it '101文字なら無効であること' do
        song.musical_key = 'a' * 101
        expect(song.valid?).to eq false
      end
    end

    context 'capo' do
      it 'nilなら有効であること' do
        song.capo = nil
        expect(song.valid?).to eq true
      end

      it '0なら有効であること' do
        song.capo = 0
        expect(song.valid?).to eq true
      end

      it '1なら有効であること' do
        song.capo = 1
        expect(song.valid?).to eq true
      end

      it '12なら有効であること' do
        song.capo = 12
        expect(song.valid?).to eq true
      end

      it '-1なら無効であること' do
        song.capo = -1
        expect(song.valid?).to eq false
      end

      it '13なら無効であること' do
        song.capo = 13
        expect(song.valid?).to eq false
      end

      it '小数なら無効であること' do
        song.capo = 1.5
        expect(song.valid?).to eq false
      end

      it '数値でない文字列なら無効であること' do
        song.capo = 'abc'
        expect(song.valid?).to eq false
      end
    end

    context 'chord_sheet_note' do
      it '空欄なら有効であること' do
        song.chord_sheet_note = ''
        expect(song.valid?).to eq true
      end

      it '300文字なら有効であること' do
        song.chord_sheet_note = 'a' * 300
        expect(song.valid?).to eq true
      end

      it '301文字なら無効であること' do
        song.chord_sheet_note = 'a' * 301
        expect(song.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Eventモデルとの関係' do
      it 'eventとN:1となっている' do
        expect(Song.reflect_on_association(:event).macro).to eq :belongs_to
      end
    end
    context 'customerモデルとの関係' do
      it 'customerモデルと1:Nとなっている' do
        expect(Song.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルsong_customersと1:Nとなっている' do
        expect(Song.reflect_on_association(:song_customers).macro).to eq :has_many
      end
    end
    context 'JoinPartモデルとの関係' do
      it 'join_partと1:Nとなっている' do
        expect(Song.reflect_on_association(:join_parts).macro).to eq :has_many
      end
    end
    context 'requested_by_customerモデルとの関係' do
      it 'requested_by_customerとN:1となっている' do
        expect(Song.reflect_on_association(:requested_by_customer).macro).to eq :belongs_to
      end
    end
  end

  describe '#recruiting_join_parts' do
    it '参加者が0人のパートのみを返すこと' do
      empty_part = FactoryBot.create(:join_part, song: song, join_part_name: 'ギター')
      filled_part = FactoryBot.create(:join_part, song: song, join_part_name: 'ベース')
      FactoryBot.create(:join_part_customer, join_part: filled_part, customer: other_customer)

      expect(song.recruiting_join_parts).to eq [empty_part]
    end

    it '全パートに参加者がいる場合は空配列を返すこと' do
      part = FactoryBot.create(:join_part, song: song, join_part_name: 'ボーカル')
      FactoryBot.create(:join_part_customer, join_part: part, customer: other_customer)

      expect(song.recruiting_join_parts).to eq []
    end

    it 'パートが存在しない場合は空配列を返すこと' do
      expect(song.recruiting_join_parts).to eq []
    end
  end

  describe '#established? / #recruiting?' do
    it '現役参加者が0人のパートが1つも無ければ成立とみなすこと' do
      part = FactoryBot.create(:join_part, song: song, join_part_name: 'ボーカル')
      FactoryBot.create(:join_part_customer, join_part: part, customer: other_customer)

      expect(song.established?).to eq true
      expect(song.recruiting?).to eq false
    end

    it '現役参加者が0人のパートが1つでもあれば募集中とみなすこと' do
      FactoryBot.create(:join_part, song: song, join_part_name: 'ギター')
      filled = FactoryBot.create(:join_part, song: song, join_part_name: 'ベース')
      FactoryBot.create(:join_part_customer, join_part: filled, customer: other_customer)

      expect(song.established?).to eq false
      expect(song.recruiting?).to eq true
    end

    it '退会ユーザーだけのパートは埋まっていないものとして扱うこと' do
      part = FactoryBot.create(:join_part, song: song, join_part_name: 'ドラム')
      withdrawn = FactoryBot.create(:customer, is_deleted: true)
      FactoryBot.create(:join_part_customer, join_part: part, customer: withdrawn)

      expect(song.established?).to eq false
    end

    it 'Public::EventsController#show の既存判定と同じく、パートが0件なら成立扱いになること' do
      expect(song.join_parts).to be_empty
      expect(song.established?).to eq true
    end
  end

  describe '#requested_by_customer' do
    let(:member) { FactoryBot.create(:customer, name: "参加太郎") }
    let(:other_member) { FactoryBot.create(:customer, name: "参加次郎") }
    let(:outsider) { FactoryBot.create(:customer, name: "部外者花子") }

    before do
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
      CommunityCustomer.find_or_create_by!(customer: other_member, community: community)
    end

    it '未設定で保存できること' do
      new_song = FactoryBot.build(:song, event: event, requested_by_customer_id: nil)
      expect(new_song).to be_valid
    end

    it '有効なコミュニティメンバーを新規設定できること' do
      new_song = FactoryBot.build(:song, event: event, requested_by_customer_id: member.id)
      expect(new_song).to be_valid
    end

    it 'イベントに参加登録していないコミュニティメンバーでも新規設定できること' do
      # memberはCommunityCustomerのみでjoin_part_customer(イベント参加)は一切作成していない。
      # 候補条件が「コミュニティ所属メンバー ∩ イベント参加者」になっていないことを保証する。
      expect(song.join_parts.flat_map(&:customers)).not_to include(member)

      new_song = FactoryBot.build(:song, event: event, requested_by_customer_id: member.id)
      expect(new_song).to be_valid
    end

    it 'コミュニティ外Customerを新規設定できないこと' do
      new_song = FactoryBot.build(:song, event: event, requested_by_customer_id: outsider.id)
      expect(new_song).to be_invalid
      expect(new_song.errors[:requested_by_customer]).to be_present
    end

    it 'イベント参加者であっても、開催コミュニティに所属していなければ新規設定できないこと' do
      join_part = FactoryBot.create(:join_part, song: song, join_part_name: 'ギター')
      FactoryBot.create(:join_part_customer, join_part: join_part, customer: outsider)

      new_song = FactoryBot.build(:song, event: event, requested_by_customer_id: outsider.id)
      expect(new_song).to be_invalid
      expect(new_song.errors[:requested_by_customer]).to be_present
    end

    it '論理削除済みCustomerを新規設定できないこと' do
      member.update!(is_deleted: true)
      new_song = FactoryBot.build(:song, event: event, requested_by_customer_id: member.id)
      expect(new_song).to be_invalid
    end

    it '設定済みのリクエスト者をnilへ解除できること' do
      song.update!(requested_by_customer_id: member.id)
      expect(song.update(requested_by_customer_id: nil)).to eq true
      expect(song.reload.requested_by_customer_id).to be_nil
    end

    it '同じCustomerを複数曲へ設定できること' do
      song.update!(requested_by_customer_id: member.id)
      other_song = FactoryBot.build(:song, event: event, requested_by_customer_id: member.id)
      expect(other_song).to be_valid
    end

    it 'eventが未設定でも例外が発生しないこと' do
      unattached_song = Song.new(song_name: "unattached", requested_by_customer_id: member.id)
      expect { unattached_song.valid? }.not_to raise_error
    end

    it '登録後にリクエスト者が退会しても、他のSong属性を更新できること' do
      song.update!(requested_by_customer_id: member.id)
      CommunityCustomer.find_by!(customer: member, community: community).destroy!

      expect(song.update(song_name: "更新後の曲名")).to eq true
      expect(song.reload.song_name).to eq "更新後の曲名"
      expect(song.reload.requested_by_customer_id).to eq member.id
    end

    it '登録後にリクエスト者が論理削除されても、他のSong属性を更新できること' do
      song.update!(requested_by_customer_id: member.id)
      member.update!(is_deleted: true)

      expect(song.update(song_name: "更新後の曲名2")).to eq true
      expect(song.reload.song_name).to eq "更新後の曲名2"
      expect(song.reload.requested_by_customer_id).to eq member.id
    end

    it '退会済みCustomerから別の有効メンバーへ変更できること' do
      song.update!(requested_by_customer_id: member.id)
      CommunityCustomer.find_by!(customer: member, community: community).destroy!

      expect(song.update(requested_by_customer_id: other_member.id)).to eq true
      expect(song.reload.requested_by_customer_id).to eq other_member.id
    end

    it '退会済みCustomerを解除できること' do
      song.update!(requested_by_customer_id: member.id)
      CommunityCustomer.find_by!(customer: member, community: community).destroy!

      expect(song.update(requested_by_customer_id: nil)).to eq true
      expect(song.reload.requested_by_customer_id).to be_nil
    end

    it '解除後、退会済みのCustomerを再設定することはできないこと' do
      song.update!(requested_by_customer_id: member.id)
      CommunityCustomer.find_by!(customer: member, community: community).destroy!
      song.update!(requested_by_customer_id: nil)

      expect(song.update(requested_by_customer_id: member.id)).to eq false
      expect(song.errors[:requested_by_customer]).to be_present
    end
  end

  describe '#capo_label' do
    it 'capoがnilの場合はnilを返すこと' do
      song.capo = nil
      expect(song.capo_label).to eq nil
    end

    it 'capoが0の場合は"なし"を返すこと' do
      song.capo = 0
      expect(song.capo_label).to eq 'なし'
    end

    it 'capoが1の場合は"1"を返すこと' do
      song.capo = 1
      expect(song.capo_label).to eq '1'
    end

    it 'capoが12の場合は"12"を返すこと' do
      song.capo = 12
      expect(song.capo_label).to eq '12'
    end
  end
end
