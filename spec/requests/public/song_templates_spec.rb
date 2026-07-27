require 'rails_helper'

RSpec.describe "Public::SongTemplates", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community, owner_id: customer.id) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { event.songs.first }

  before do
    CommunityOwner.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  describe 'ログイン済み' do
    before { sign_in customer }

    describe 'create' do
      it '権限を持つCustomerがSongからテンプレートを作成できること' do
        expect do
          post public_community_song_templates_path(community), params: { song_id: song.id }
        end.to change(SongTemplate, :count).by(1)
      end

      it 'Songの対象属性が正しくコピーされること' do
        song.update!(
          artist_name: "テストアーティスト",
          youtube_url: "https://youtube.com/watch?v=xxx",
          introduction: "紹介文",
          chord_sheet_url: "https://example.com/chord-sheet",
          tab_sheet_url: "https://example.com/tab-sheet",
          musical_key: "G",
          capo: 2,
          chord_sheet_note: "初心者向けの簡単コード版です"
        )

        post public_community_song_templates_path(community), params: { song_id: song.id }

        template = SongTemplate.last
        expect(template.song_name).to eq song.song_name
        expect(template.artist_name).to eq "テストアーティスト"
        expect(template.youtube_url).to eq "https://youtube.com/watch?v=xxx"
        expect(template.introduction).to eq "紹介文"
        expect(template.chord_sheet_url).to eq "https://example.com/chord-sheet"
        expect(template.tab_sheet_url).to eq "https://example.com/tab-sheet"
        expect(template.musical_key).to eq "G"
        expect(template.capo).to eq 2
        expect(template.chord_sheet_note).to eq "初心者向けの簡単コード版です"
      end

      it 'performance_time/performance_start_time/position/join_partsがコピーされないこと' do
        song.update!(performance_time: "5:00", performance_start_time: "19:00")
        FactoryBot.create(:join_part, song: song)

        post public_community_song_templates_path(community), params: { song_id: song.id }

        template = SongTemplate.last
        expect(template).not_to respond_to(:performance_time)
        expect(template).not_to respond_to(:performance_start_time)
        expect(template).not_to respond_to(:position)
        expect(template).not_to respond_to(:join_parts)
      end

      it 'source_song_idが正しく設定されること' do
        post public_community_song_templates_path(community), params: { song_id: song.id }

        expect(SongTemplate.last.source_song_id).to eq song.id
      end

      it '作成者(customer_id)が現在のログインCustomerになること' do
        post public_community_song_templates_path(community), params: { song_id: song.id }

        expect(SongTemplate.last.customer_id).to eq customer.id
      end

      it '他Communityのイベント配下のSongを不正にテンプレート化できないこと' do
        other_community = FactoryBot.create(:community, owner_id: other_customer.id)
        other_event = FactoryBot.create(:event, :event_with_songs, customer: other_customer, community: other_community)
        other_song = other_event.songs.first

        expect do
          post public_community_song_templates_path(community), params: { song_id: other_song.id }
        end.not_to change(SongTemplate, :count)

        expect(response.status).to eq 302
      end

      it '同じSongから複数回テンプレートを作成できること' do
        post public_community_song_templates_path(community), params: { song_id: song.id }

        expect do
          post public_community_song_templates_path(community), params: { song_id: song.id }
        end.to change(SongTemplate, :count).by(1)
      end

      context '一般メンバーで権限がない場合' do
        before do
          CommunityCustomer.find_or_create_by!(customer: other_customer, community: community)
        end

        it 'テンプレートを作成できないこと' do
          sign_in other_customer

          expect do
            post public_community_song_templates_path(community), params: { song_id: song.id }
          end.not_to change(SongTemplate, :count)
        end
      end
    end

    describe 'destroy' do
      it '作成者本人が削除できること' do
        template = FactoryBot.create(:song_template, community: community, customer: customer)

        expect do
          delete public_community_song_template_path(community, template)
        end.to change(SongTemplate, :count).by(-1)
      end

      it 'Community管理者が削除できること' do
        template = FactoryBot.create(:song_template, community: community, customer: other_customer)

        expect do
          delete public_community_song_template_path(community, template)
        end.to change(SongTemplate, :count).by(-1)
      end

      it '他の一般メンバーは削除できないこと' do
        CommunityCustomer.find_or_create_by!(customer: other_customer, community: community)
        template = FactoryBot.create(:song_template, community: community, customer: customer)

        sign_in other_customer
        expect do
          delete public_community_song_template_path(community, template)
        end.not_to change(SongTemplate, :count)
      end

      it '他Communityのテンプレートを削除できないこと' do
        other_community = FactoryBot.create(:community, owner_id: other_customer.id)
        template = FactoryBot.create(:song_template, community: other_community, customer: other_customer)

        expect do
          delete public_community_song_template_path(other_community, template)
        end.not_to change(SongTemplate, :count)
      end

      it '削除後も既存Event Songは残ること' do
        template = FactoryBot.create(:song_template, community: community, customer: customer, source_song: song)

        delete public_community_song_template_path(community, template)

        expect(Song.exists?(song.id)).to eq true
      end
    end
  end

  describe '非ログイン' do
    it 'createできないこと' do
      expect do
        post public_community_song_templates_path(community), params: { song_id: song.id }
      end.not_to change(SongTemplate, :count)

      expect(response.status).to eq 302
    end

    it 'destroyできないこと' do
      template = FactoryBot.create(:song_template, community: community, customer: customer)

      expect do
        delete public_community_song_template_path(community, template)
      end.not_to change(SongTemplate, :count)

      expect(response.status).to eq 302
    end
  end
end
