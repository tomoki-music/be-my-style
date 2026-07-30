require 'rails_helper'

RSpec.describe "Public::CommunityEventEditors", type: :request do
  let(:owner) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id) }
  let(:member) { FactoryBot.create(:customer) }

  before do
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
  end

  describe 'オーナーによる操作' do
    before { sign_in owner }

    it 'コミュニティメンバーをイベント編集者に設定できること' do
      expect do
        post public_community_community_event_editors_path(community), params: { customer_id: member.id }
      end.to change(CommunityEventEditor, :count).by(1)

      expect(CommunityEventEditor.exists?(community: community, customer: member)).to eq true
    end

    it 'イベント編集者を解除できること' do
      community_event_editor = CommunityEventEditor.create!(customer: member, community: community)

      expect do
        delete public_community_community_event_editor_path(community, community_event_editor)
      end.to change(CommunityEventEditor, :count).by(-1)
    end

    it '他コミュニティのメンバーへは設定できないこと' do
      other_community = FactoryBot.create(:community)
      outsider = FactoryBot.create(:customer)
      CommunityCustomer.find_or_create_by!(customer: outsider, community: other_community)

      expect do
        post public_community_community_event_editors_path(community), params: { customer_id: outsider.id }
      end.not_to change(CommunityEventEditor, :count)
    end

    it 'すでにオーナーであるユーザーへは重複登録しないこと' do
      expect do
        post public_community_community_event_editors_path(community), params: { customer_id: owner.id }
      end.not_to change(CommunityEventEditor, :count)
    end
  end

  describe '管理者による操作' do
    let(:admin_customer) { FactoryBot.create(:customer) }

    before do
      admin_customer.update!(is_owner: :admin)
      sign_in admin_customer
    end

    it 'イベント編集者を設定できること' do
      expect do
        post public_community_community_event_editors_path(community), params: { customer_id: member.id }
      end.to change(CommunityEventEditor, :count).by(1)
    end

    it 'イベント編集者を解除できること' do
      community_event_editor = CommunityEventEditor.create!(customer: member, community: community)

      expect do
        delete public_community_community_event_editor_path(community, community_event_editor)
      end.to change(CommunityEventEditor, :count).by(-1)
    end
  end

  describe '権限のないユーザーによる操作' do
    it '一般メンバーは設定できないこと' do
      sign_in member

      expect do
        post public_community_community_event_editors_path(community), params: { customer_id: member.id }
      end.not_to change(CommunityEventEditor, :count)
      expect(response.status).to eq 302
    end

    it '他コミュニティのオーナーは設定できないこと' do
      other_owner = FactoryBot.create(:customer)
      other_community = FactoryBot.create(:community, owner_id: other_owner.id)
      CommunityOwner.find_or_create_by!(customer: other_owner, community: other_community)
      sign_in other_owner

      expect do
        post public_community_community_event_editors_path(community), params: { customer_id: member.id }
      end.not_to change(CommunityEventEditor, :count)
      expect(response.status).to eq 302
    end

    it 'イベント編集者本人は自分自身を解除できないこと' do
      community_event_editor = CommunityEventEditor.create!(customer: member, community: community)
      sign_in member

      expect do
        delete public_community_community_event_editor_path(community, community_event_editor)
      end.not_to change(CommunityEventEditor, :count)
      expect(response.status).to eq 302
    end
  end
end
