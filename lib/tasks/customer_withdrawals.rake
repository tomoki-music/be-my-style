namespace :customers do
  namespace :withdrawal do
    # 退会後のファイル削除(プロフィール画像・歌声の音声・共有画像・振り返り動画)を再実行する。
    # 退会時の削除が外部ストレージの障害などで失敗した場合に使う。削除済みのものは対象にならないため、何度実行してもよい。
    #   bundle exec rails customers:withdrawal:purge_files
    #   CUSTOMER_ID=123 bundle exec rails customers:withdrawal:purge_files
    desc "退会した会員のファイル削除を再実行する"
    task purge_files: :environment do
      scope = Customer.where.not(withdrawn_at: nil)
      scope = scope.where(id: ENV["CUSTOMER_ID"]) if ENV["CUSTOMER_ID"].present?

      total_failures = 0
      scope.find_each do |customer|
        failures = Customers::Withdrawal::PurgeFiles.call(customer)
        total_failures += failures
        puts "customer_id=#{customer.id} failures=#{failures}"
      end
      puts "done failures=#{total_failures}"
    end
  end
end
