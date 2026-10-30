# ログインが必要な画面を未ログインで開いたとき・ログインに失敗したとき(メール未確認・退会済みなど)の戻り先。
# Devise の既定は音楽のログイン画面(/customers/sign_in)のため、Business の画面から来た人もそこへ戻され、
# そこでログインすると音楽トップを経由して「音楽プラットフォームの利用には…」の案内が出ていた。
# Business の画面・ログインからの失敗だけ Business のログイン画面へ戻し、音楽・歌声側は既定のままにする。
class CustomerAuthFailureApp < Devise::FailureApp
  def route(scope)
    return :new_business_customer_session_url if scope.to_s == "customer" && business_request?

    super
  end

  private

  # Warden は失敗アプリを呼ぶ前に PATH_INFO を書き換えるため、元のリクエストのパスは attempted_path で見る。
  def business_request?
    path = URI.parse(attempted_path.to_s).path.to_s
    path == "/business" || path.start_with?("/business/")
  rescue URI::InvalidURIError
    false
  end
end
