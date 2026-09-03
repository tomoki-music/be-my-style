require 'rails_helper'

# Stampable は Request / ChatMessage / Comment / Message で共有される concern。
# ここではスタンプキーの許可リスト・後方互換・表示解決・「本文 or スタンプ必須」を検証する。
RSpec.describe Stampable, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:chat_room) { FactoryBot.create(:chat_room) }

  def build_request(attrs = {})
    Request.new({ customer: customer, event: event, request: nil }.merge(attrs))
  end

  def build_chat_message(attrs = {})
    ChatMessage.new({ customer: customer, chat_room: chat_room, content: nil }.merge(attrs))
  end

  describe '許可されたスタンプキーのみ保存できる' do
    it 'イラストスタンプ26種(シンプル10 / 人物10 / どうぶつ6)すべてを stamp_type に保存できる' do
      by_category = Stampable::STAMP_DEFINITIONS.values.group_by { |definition| definition[:category] }
      expect(by_category[:simple].size).to eq 10
      expect(by_category[:human].size).to eq 10
      expect(by_category[:animal].size).to eq 6
      expect(Stampable::STAMP_DEFINITIONS.keys.size).to eq 26

      Stampable::STAMP_DEFINITIONS.each_key do |key|
        record = build_request(stamp_type: key)
        expect(record).to be_valid, "#{key} が有効になっていない"
      end
    end

    it 'レガシー絵文字5種を含めた許可リストになっている' do
      expect(Stampable::LEGACY_STAMP_LABELS.keys.size).to eq 5
      expect(Stampable::VALID_STAMP_TYPES).to match_array(Stampable::STAMP_DEFINITIONS.keys | Stampable::LEGACY_STAMP_LABELS.keys)
      Stampable::LEGACY_STAMP_LABELS.each_key do |key|
        expect(Stampable::VALID_STAMP_TYPES).to include(key)
      end
    end

    it '本文のみ（スタンプなし）の投稿を保存できる' do
      expect(build_request(request: 'この曲をお願いします！')).to be_valid
    end

    it 'スタンプのみ（本文なし）の投稿を保存できる' do
      expect(build_request(stamp_type: 'like')).to be_valid
    end

    it '本文もスタンプも無い投稿は保存できない' do
      record = build_request
      expect(record).to be_invalid
      expect(record.errors[:base]).to be_present
    end
  end

  describe '不正な値を拒否する（セキュリティ）' do
    invalid_values = {
      '存在しないキー' => 'not_a_real_stamp',
      '任意URL' => 'https://evil.example.com/x.svg',
      'プロトコル相対URL' => '//evil.example.com/x.svg',
      'HTMLタグ' => '<img src=x onerror=alert(1)>',
      'JavaScript' => 'javascript:alert(1)',
      'パストラバーサル' => '../../../../etc/passwd',
      'アセットパス直接指定' => 'stamps/stamp_like.svg',
      '許可リスト外の空白付きキー' => ' like '
    }

    invalid_values.each do |label, value|
      it "#{label}（#{value.inspect}）は stamp_type に保存できない" do
        record = build_request(stamp_type: value)
        expect(record).to be_invalid
        expect(record.errors[:stamp_type]).to be_present
      end
    end
  end

  describe '後方互換（レガシー絵文字スタンプ）' do
    Stampable::LEGACY_STAMP_LABELS.each_key do |legacy_key|
      it "既存レコードのレガシーキー #{legacy_key.inspect} は引き続き有効" do
        expect(build_chat_message(stamp_type: legacy_key)).to be_valid
      end
    end

    it 'レガシーキーの stamp_label は従来どおり絵文字ラベルを返す' do
      expect(build_chat_message(stamp_type: 'clap').stamp_label).to eq '👏 ナイス！'
    end

    it 'レガシーキーは illustration_stamp? が false（SVG表示しない）' do
      expect(build_chat_message(stamp_type: 'clap').illustration_stamp?).to eq false
    end

    it 'スタンプ未設定の既存レコードは通常投稿として有効なまま' do
      expect(build_chat_message(content: 'こんにちは')).to be_valid
      expect(build_chat_message(content: 'こんにちは').stamped?).to eq false
    end
  end

  describe '表示責務の解決' do
    it 'illustration_stamp? はイラストスタンプキーのときだけ true' do
      expect(build_request(stamp_type: 'like').illustration_stamp?).to eq true
      expect(build_request(stamp_type: nil).illustration_stamp?).to eq false
    end

    it 'stamp_definition は label / asset / category を返す' do
      definition = build_request(stamp_type: 'thanks').stamp_definition
      expect(definition[:label]).to eq 'ありがとう'
      expect(definition[:asset]).to eq 'stamps/stamp_thanks.svg'
      expect(definition[:category]).to eq :simple
    end

    it '人物・どうぶつスタンプも stamp_label / illustration_stamp? が解決する' do
      expect(build_request(stamp_type: 'character_doing_great').stamp_label).to eq '快調です'
      expect(build_request(stamp_type: 'character_doing_great').illustration_stamp?).to eq true
      expect(build_request(stamp_type: 'animal_got_it').stamp_label).to eq '了解！'
      expect(build_request(stamp_type: 'animal_got_it').illustration_stamp?).to eq true
    end

    it 'stamp_label はイラストスタンプの日本語名を返す' do
      expect(build_request(stamp_type: 'doing_great').stamp_label).to eq '快調です'
    end

    it 'アセットパスはすべて stamps/ 配下の .svg / .png（外部URLでない）' do
      Stampable::STAMP_DEFINITIONS.each_value do |definition|
        expect(definition[:asset]).to match(%r{\Astamps/stamp_[a-z_]+\.(svg|png)\z})
      end
    end

    it 'カテゴリ別の定義一覧(definitions_by_category)がタブ順で 10 / 10 / 6 件を返す' do
      by_category = Stampable.definitions_by_category
      expect(by_category.keys).to eq %i[simple human animal]
      expect(by_category[:simple].size).to eq 10
      expect(by_category[:human].size).to eq 10
      expect(by_category[:animal].size).to eq 6
    end
  end
end
