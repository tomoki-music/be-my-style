require "rails_helper"

RSpec.describe "イベント新規作成の主催コミュニティの認可", type: :request do
  let(:manager) { FactoryBot.create(:customer, is_owner: :community_owner) }
  let(:other_owner) { FactoryBot.create(:customer) }
  let(:managed) { FactoryBot.create(:community, name: "自分のコミュニティ", owner_id: manager.id) }
  let(:unmanaged) { FactoryBot.create(:community, name: "他人のコミュニティ", owner_id: other_owner.id) }

  before do
    CommunityOwner.create!(customer: manager, community: managed)
    sign_in manager
  end

  def create_params(community_id, name: "作成確認イベント")
    {
      event: {
        community_id: community_id,
        event_name: name,
        event_start_time: 30.days.from_now,
        event_end_time: 30.days.from_now + 2.hours,
        event_entry_deadline: 20.days.from_now,
        entrance_fee: 1000,
        place: "スタジオ",
        address: "埼玉県さいたま市",
        songs_attributes: { "0" => { song_name: "曲", join_parts_attributes: { "0" => { join_part_name: "Vocal" } } } }
      }
    }
  end

  describe "権限の無いコミュニティを主催として保存できない" do
    it "クエリに権限のあるコミュニティを指定しても、本文の権限の無いコミュニティでは作成できない" do
      expect do
        post public_events_path(community_id: managed.id), params: create_params(unmanaged.id)
      end.not_to change(Event, :count)

      expect(response).to redirect_to(public_events_path)
      expect(flash[:alert]).to eq "イベントを作成する権限がありません。"
    end

    it "クエリが無くても権限の無いコミュニティでは作成できない" do
      expect { post public_events_path, params: create_params(unmanaged.id) }.not_to change(Event, :count)

      expect(response).to redirect_to(public_events_path)
    end

    it "Premium 必須のコミュニティの判定をクエリで回避できない" do
      premium = FactoryBot.create(:community, :premium_origin, owner_id: other_owner.id)

      expect do
        post public_events_path(community_id: managed.id), params: create_params(premium.id)
      end.not_to change(Event, :count)

      expect(response).to redirect_to(public_community_path(premium))
    end

    it "別ドメインのコミュニティをクエリで回避して主催にできない" do
      business = FactoryBot.create(:community, owner_id: manager.id, domain: Domain.find_or_create_by!(name: "business"))
      CommunityOwner.create!(customer: manager, community: business)

      expect do
        post public_events_path(community_id: managed.id), params: create_params(business.id)
      end.not_to change(Event, :count)

      expect(response).to redirect_to(public_events_path)
      expect(flash[:alert]).to eq "イベントを作成するコミュニティを確認してください。"
    end

    [
      ["存在しないID", "99999999"],
      ["数字以外が混ざる値", "%{id}abc"],
      ["0", "0"],
      ["配列", ["%{id}"]],
      ["ハッシュ", { "id" => "%{id}" }]
    ].each do |label, raw|
      it "本文の主催が#{label}なら作成せず、エラー画面にもしない" do
        value = raw.is_a?(String) ? format(raw, id: unmanaged.id) : raw
        value = [unmanaged.id.to_s] if raw.is_a?(Array)
        value = { "id" => unmanaged.id.to_s } if raw.is_a?(Hash)

        expect do
          post public_events_path(community_id: managed.id), params: create_params(value)
        end.not_to change(Event, :count)

        expect(response).to redirect_to(public_events_path)
      end
    end

    it "権限の無いコミュニティのメンバーをリクエスト者の候補やテンプレートとして返さない" do
      other_member = FactoryBot.create(:customer, name: "他人のメンバーさん")
      CommunityCustomer.create!(customer: other_member, community: unmanaged)
      params = create_params(managed.id, name: "")

      post public_events_path(community_id: unmanaged.id), params: params

      expect(response.status).to eq 200
      expect(response.body).not_to include("他人のメンバーさん")
      expect(Nokogiri::HTML(response.body).css("[name='event[community_id]']").first["value"].to_i).to eq managed.id
    end

    context "保存前プレビュー" do
      let(:json_headers) { { "ACCEPT" => "application/json" } }

      def preview(query_community, body_community)
        post deadline_reminder_preview_public_events_path(community_id: query_community.id),
          params: { event: { community_id: body_community.id }, reminder: { kind: "entry" } }, headers: json_headers
      end

      it "クエリに権限のあるコミュニティを指定しても、本文の権限の無いコミュニティでは権限エラーにする" do
        expect(EventDeadlineReminders::FormPreview).not_to receive(:new)

        preview(managed, unmanaged)

        expect(response.status).to eq 403
        expect(JSON.parse(response.body)["error"]).to eq "イベントを作成する権限がありません。"
      end

      it "認可した本文の主催をプレビューに使い、クエリのコミュニティは使わない" do
        used_community = nil
        allow(EventDeadlineReminders::FormPreview).to receive(:new).and_wrap_original do |original, **arguments|
          used_community = arguments[:event].community
          original.call(**arguments)
        end

        preview(unmanaged, managed)

        expect(response.status).to eq 200
        expect(used_community).to eq managed
      end
    end
  end

  describe "正規の作成フロー" do
    it "コミュニティを選んで開いた画面の値で、そのコミュニティを主催に作成できる" do
      get new_public_event_path(community_id: managed.id)
      expect(response.status).to eq 200
      hidden = Nokogiri::HTML(response.body).css("input[name='event[community_id]']").first

      expect { post public_events_path, params: create_params(hidden["value"]) }.to change(Event, :count).by(1)

      created = Event.order(:id).last
      expect(response).to redirect_to(public_event_path(created))
      expect(created.community).to eq managed
      expect(created.customer).to eq manager
    end

    it "クエリと本文が同じコミュニティでも作成できる" do
      expect do
        post public_events_path(community_id: managed.id), params: create_params(managed.id)
      end.to change(Event, :count).by(1)

      expect(Event.order(:id).last.community).to eq managed
    end

    it "クエリに権限の無いコミュニティがあっても、本文の権限のあるコミュニティが主催になる" do
      expect do
        post public_events_path(community_id: unmanaged.id), params: create_params(managed.id)
      end.to change(Event, :count).by(1)

      expect(Event.order(:id).last.community).to eq managed
    end

    it "画面のセレクトで選んだコミュニティでも作成できる" do
      get new_public_event_path
      options = Nokogiri::HTML(response.body).css("select[name='event[community_id]'] option").map { |option| option["value"].to_i }
      expect(options).to include(managed.id)
      expect(options).not_to include(unmanaged.id)

      expect { post public_events_path, params: create_params(managed.id) }.to change(Event, :count).by(1)
    end

    it "入力エラーのときは選んだコミュニティのまま再表示する" do
      expect { post public_events_path, params: create_params(managed.id, name: "") }.not_to change(Event, :count)

      expect(response.status).to eq 200
      expect(Nokogiri::HTML(response.body).css("input[name='event[community_id]']").first["value"].to_i).to eq managed.id
    end

    it "コピー画面から同じコミュニティで作成できる" do
      source = FactoryBot.create(:event, :event_with_songs, customer: manager, community: managed)

      get copy_public_event_path(source)
      hidden = Nokogiri::HTML(response.body).css("input[name='event[community_id]']").first
      expect(hidden["value"].to_i).to eq managed.id

      expect { post public_events_path, params: create_params(hidden["value"]) }.to change(Event, :count).by(1)
      expect(Event.order(:id).last.community).to eq managed
    end

    it "別のコミュニティを指定したコピー画面を開いても、権限が無ければ保存できない" do
      source = FactoryBot.create(:event, :event_with_songs, customer: manager, community: managed)

      get copy_public_event_path(source, community_id: unmanaged.id)
      hidden = Nokogiri::HTML(response.body).css("input[name='event[community_id]']").first

      expect { post public_events_path, params: create_params(hidden["value"]) }.not_to change(Event, :count)
      expect(response).to redirect_to(public_events_path)
    end

    it "サイト管理者はどのコミュニティでも作成できる" do
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      expect { post public_events_path, params: create_params(unmanaged.id) }.to change(Event, :count).by(1)
      expect(Event.order(:id).last.community).to eq unmanaged
    end
  end
end
