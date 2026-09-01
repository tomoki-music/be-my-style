require 'rails_helper'

RSpec.describe Customer, type: :system do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }

  describe 'custmer新規登録のテスト' do
    before do
      visit new_customer_registration_path
    end
    context 'フォームの入力値が正常' do
      it 'customerの新規作成が成功' do
        fill_in 'customer_name', with: 'customer'
        fill_in 'customer_email', with: 'person@example.com'
        fill_in 'customer_password', with: 'password'
        fill_in 'customer_password_confirmation', with: 'password'
        click_button '新規登録する'
        expect(current_path).to eq public_homes_top_path
        expect(page).to have_content 'アカウント登録が完了しました'
      end
    end
    context '名前・ニックネーム未記入' do
      it 'customerの新規作成が失敗' do
        fill_in 'customer_name', with: nil
        fill_in 'customer_email', with: 'person@example.com'
        fill_in 'customer_password', with: 'password'
        fill_in 'customer_password_confirmation', with: 'password'
        click_button '新規登録する'
        expect(current_path).to eq customer_registration_path
        expect(page).to have_content '名前を入力してください'
      end
    end
    context '名前・ニックネームが21文字以上' do
      it 'customerの新規作成が失敗' do
        fill_in 'customer_name', with: 'testtesttesttesttest1'
        fill_in 'customer_email', with: 'person@example.com'
        fill_in 'customer_password', with: 'password'
        fill_in 'customer_password_confirmation', with: 'password'
        click_button '新規登録する'
        expect(current_path).to eq customer_registration_path
        expect(page).to have_content '名前は20文字以内で入力してください'
      end
    end
    context 'メールアドレス未記入' do
      it 'customerの新規作成が失敗' do
        fill_in 'customer_name', with: 'customer'
        fill_in 'customer_email', with: nil
        fill_in 'customer_password', with: 'password'
        fill_in 'customer_password_confirmation', with: 'password'
        click_button '新規登録する'
        expect(current_path).to eq customer_registration_path
        expect(page).to have_content 'メールアドレスを入力してください'
      end
    end
    context '登録済メールアドレス' do
      it 'customerの新規作成が失敗' do
        fill_in 'customer_name', with: 'customer'
        fill_in 'customer_email', with: customer.email
        fill_in 'customer_password', with: 'password'
        fill_in 'customer_password_confirmation', with: 'password'
        click_button '新規登録する'
        expect(current_path).to eq customer_registration_path
        expect(page).to have_content 'メールアドレスはすでに存在します'
      end
    end
  end

  describe 'custmerログインのテスト' do
    before do
      visit new_customer_session_path
    end
    context 'フォームの入力値が正常' do
      it 'customerのログインが成功' do
        fill_in 'customer_name', with: customer.name
        fill_in 'customer_email', with: customer.email
        fill_in 'customer_password', with: customer.password
        click_button 'ログインする'
        expect(current_path).to eq public_homes_top_path
        expect(page).to have_content 'ログインしました'
      end
    end
    context 'フォームの入力値が不正' do
      it 'customerのログインが失敗' do
        fill_in 'customer_name', with: nil
        fill_in 'customer_email', with: nil
        fill_in 'customer_password', with: nil
        click_button 'ログインする'
        expect(current_path).to eq new_customer_session_path
        expect(page).to have_content 'メールアドレスまたはパスワードが違います。'
      end
    end
  end

  describe 'アーティストの画面テスト' do
    before do
      login(customer)
    end
    describe 'Top画面の表示のテスト' do
      context 'TOP画面' do
        before do
          visit public_homes_top_path
        end
        it 'Top画面が表示される' do
          expect(current_path).to eq('/public/homes/top')
        end
      end
    end
    describe 'Artist詳細のテスト' do
      context 'Artist詳細画面への遷移' do
        before do
          visit public_customers_path
        end
        it 'Artist詳細画面へ遷移できる' do
          within('.customer-menu-sp') { click_link 'マイページ' }
          expect(current_path).to eq('/public/customers/' + customer.id.to_s)
        end
      end
      context 'Artist詳細画項目が表示される' do
        before do
          visit public_customer_path(customer)
        end
        it 'Artist詳細画面の各項目の表示' do
          expect(page).to have_content "Customer"
          expect(page).to have_content 'Part'
        end
        it 'プロフィール編集ボタンが表示される' do
          within('.customer-show-follow') do
            expect(page).to have_link 'プロフィール編集', href: edit_public_customer_path(customer)
          end
        end
      end
      context 'Artistのフォローができる' do
        before do
          visit public_customer_path(other_customer)
        end
        it '「フォローする」ボタンが表示される' do
          within('.customer-show-follow') do
            expect(page).to have_link 'フォローする', href: public_customer_relationships_path(other_customer.id)
          end
        end
        it '「フォローする」ボタンを押すと「フォロワー数」が1つ増え「フォロー外す」ボタンに変わる' do
          expect {
            within('.customer-show-follow') { click_link 'フォローする' }
          }.to change { Relationship.count }.by(1)
          within('.customer-show-follow') do
            expect(page).to have_link 'フォロー外す'
          end
        end
        it '「フォロー外す」ボタンを押すと「フォロワー数」が1つ減り「フォローする」ボタンに変わる' do
          within('.customer-show-follow') { click_link 'フォローする' }
          expect {
            within('.customer-show-follow') { click_link 'フォロー外す' }
          }.to change { Relationship.count }.from(1).to(0)
          within('.customer-show-follow') do
            expect(page).to have_link 'フォローする'
          end
        end
      end
    end
    describe 'Artist編集のテスト' do
      context 'Artist編集画面への遷移' do
        before do
          visit public_customer_path(customer)
        end
        it 'Artist編集画面へ遷移できる' do
          within('.customer-show-follow') { click_link 'プロフィール編集' }
          expect(current_path).to eq('/public/customers/' + customer.id.to_s + '/edit')
        end
      end
      context 'Artist編集の項目が表示される' do
        before do
          visit edit_public_customer_path(customer)
        end
        it 'Artist編集画面の各項目の表示' do
          expect(page).to have_field 'customer[name]', with: customer.name
        end
        it 'プロフィール編集ボタンが表示される' do
          expect(page).to have_button 'プロフィールを更新'
        end
      end
      context '更新処理に関するテスト' do
        before do
          visit edit_public_customer_path(customer)
        end
        it '更新に成功しサクセスメッセージが表示されるか' do
          fill_in 'customer_name', with: Faker::Lorem.characters(number:5)
          fill_in 'customer_introduction', with: Faker::Lorem.characters(number:20)
          click_button 'プロフィールを更新'
          expect(page).to have_content 'プロフィールの更新が完了しました!'
        end
        it '更新に失敗しエラーメッセージが表示されるか' do
          fill_in 'customer_name', with: ""
          fill_in 'customer_introduction', with: ""
          click_button 'プロフィールを更新'
          expect(page).to have_content '名前を入力してください'
        end
        it '更新後のリダイレクト先は正しいか' do
          fill_in 'customer_name', with: Faker::Lorem.characters(number:5)
          fill_in 'customer_introduction', with: Faker::Lorem.characters(number:20)
          click_button 'プロフィールを更新'
          expect(page).to have_current_path public_customer_path(customer)
        end
      end
    end
    describe 'Artistの相互フォロー（マッチング）のテスト' do
      before do
        matching(other_customer)
      end
        context '相互フォローの際のチャット一覧' do
          it 'チャット一覧にアーティストが表示' do
            visit public_matchings_path
            expect(page).to have_content 'さんと チャット🎵'
          end
        end
        context '相互フォローの際の該当アーティスト詳細ページにチャットアイコンが表示される' do
          before do
          
          end
          it '該当アーティスト詳細ページにチャットアイコンが表示される' do
            visit public_customer_path(customer)
            expect(page).to have_content 'チャットする'
          end
        end
    end
    describe 'Artistのチャット機能のテスト' do
      before do
        matching(other_customer)
      end
        context 'チャット画面に遷移できる' do
          it 'チャットボタンを押すとチャット画面へ遷移する' do
            visit public_matchings_path
            within('.matching-index') { click_link(href: public_chat_rooms_path(customer_id: customer.id)) }
            expect(page).to have_content 'チャットルームへようこそ!'
          end
        end
        context 'チャット入力のテスト' do
          before do
            visit public_matchings_path
            within('.matching-index') { click_link(href: public_chat_rooms_path(customer_id: customer.id)) }
          end
          it '正常にメッセージが送信できる' do
            fill_in 'chat_message_content', with: "初めまして！"
            click_button 'メッセージを送信'
            expect(page).to have_content 'メッセージを送信しました🎵'
          end
          it '空欄だとメッセージが送信できない' do
            fill_in 'chat_message_content', with: ""
            click_button 'メッセージを送信'
            expect(page).to have_content 'メッセージを入力してください！'
          end
        end
    end
    describe 'Artistへの通知テスト' do
      context 'フォローに関する通知テスト' do
        before do
          matching(other_customer)
        end
        it 'customerがother_customerをフォローすると、other_customerへ通知が届く' do
          visit public_notifications_path
          expect(page).to have_content 'さんが あなたをフォローしました'
        end
      end
      context 'チャットに関する通知テスト' do
        before do
          matching(other_customer)
          visit public_matchings_path
          within('.matching-index') { click_link(href: public_chat_rooms_path(customer_id: customer.id)) }
          fill_in 'chat_message_content', with: "初めまして！"
          click_button 'メッセージを送信'
          within('.customer-menu-sp') { click_button 'ログアウト' }
          login(customer)
        end
        it 'メッセージを送信された通知が届いている' do
          visit public_notifications_path
          expect(page).to have_content 'さんが あなたにメッセージを送信しました'
        end
      end
    end
  end
end