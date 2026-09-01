module MatchingModule
  # customer と other_customer を相互フォロー（マッチング）状態にする。
  # 画面の表示順ではなく、フォロー用リンク・ログアウトボタンを意味的に指定する。
  def matching(other_customer)
    visit public_customer_path(other_customer)
    within('.customer-show-follow') { click_link 'フォローする' }
    click_button 'ログアウト'

    login(other_customer)
    visit public_customer_path(customer)
    within('.customer-show-follow') { click_link 'フォローする' }
  end
end
