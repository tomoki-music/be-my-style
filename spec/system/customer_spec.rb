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

  describe 'Top画面、アーティスト一覧、詳細、編集への遷移、編集のテスト' do
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
    describe 'Artist一覧のテスト' do
      before do
        visit public_customers_path
      end
      context 'Artist一覧画面への遷移' do
        it 'Artist一覧画面へ遷移できる' do
          expect(current_path).to eq('/public/customers')
        end
      end
      context 'Artist一覧で名前が表示される' do
        it 'Artist一覧で必要な項目が表示される' do
          expect(page).to have_content "Customer"
          expect(page).to have_content 'Part'
        end
      end
      context 'Artist一覧でプロフィール画面へのリンクが表示される' do
        it 'プロフィール画面へのリンクが表示される' do
          show_link = find_all('a')[3]
          expect(show_link.native.inner_text).to match('プロフィール画面へ')
        end
      end
    end
    describe 'Artist詳細のテスト' do
      context 'Artist詳細画面への遷移' do
        before do
          visit public_customers_path
        end
        it 'Artist詳細画面へ遷移できる' do
          show_link = find_all('a')[3]
          show_link.click
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
          expect(find_all('a')[3].native.inner_text).to match('プロフィール編集')
        end
      end
    end
    describe 'Artist編集のテスト' do
      context 'Artist編集画面への遷移' do
        before do
          visit public_customer_path(customer)
        end
        it 'Artist編集画面へ遷移できる' do
          show_link = find_all('a')[3]
          show_link.click
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
  end
end