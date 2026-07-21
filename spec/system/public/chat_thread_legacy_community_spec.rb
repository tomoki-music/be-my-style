require "rails_helper"

# community_idが元々どこにも設定されておらず常にnilだった(既存のバグ)経緯で、
# community_id: nilのまま残っている過去のコミュニティメッセージからでも、実際のブラウザ操作で
# スレッド返信できることを確認する回帰テスト(Chat::ReplyTargetResolver修正の実ブラウザ確認)。
RSpec.describe "過去のコミュニティメッセージ(community_id: nil)からのスレッド返信", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:member) { create(:customer) }
  let(:community) { create(:community) }
  let(:community_chat_room) { create(:chat_room) }

  before do
    create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  it "community_idがnilの過去メッセージでも、スレッドパネルを開いて返信できること" do
    legacy_root = create(:chat_message, customer: member, chat_room: community_chat_room, content: "過去の投稿(community_id無し)")
    expect(legacy_root.community_id).to be_nil
    create(:chat_message, customer: customer, chat_room: community_chat_room, content: "1件目の返信",
                          reply_to_chat_message: legacy_root)

    sign_in_via_form(customer)
    visit community_show_public_chat_rooms_path(community_chat_room)

    expect(page).to have_selector(".thread-replies-button", wait: 10)
    page.evaluate_script("document.querySelector('.thread-replies-button').click();")
    expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)
    expect(page).to have_content("過去の投稿(community_id無し)")

    # .thread-reply-submitはpill状の隣接flex要素があり、Capybaraのネイティブclickに対して
    # クリック座標がずれ不安定になることがあるため(chat_thread_image_size_spec.rb等と同様)、
    # JS側で値設定・クリックイベントを直接発火させる。
    # 各メッセージのインライン編集フォーム(.message-edit-form)も.markdown-textareaを持つため、
    # `.thread-reply-form`配下に絞り込んでスレッド返信用のtextareaを specific に取得する。
    page.execute_script(<<~JS)
      var textarea = document.querySelector('#thread-panel-body .thread-reply-form textarea.markdown-textarea');
      textarea.value = 'スレッド返信します';
      textarea.dispatchEvent(new Event('input'));
      document.querySelector('#thread-panel-body .thread-reply-submit').click();
    JS

    expect(page).to have_selector("#thread-replies-list", text: "スレッド返信します", wait: 10)
    expect(legacy_root.reload.replies_count).to eq 2
    expect(ChatMessage.last.community_id).to eq community.id
  end
end
