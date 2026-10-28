# frozen_string_literal: true

namespace :business_project_threads do
  desc "「全体トーク」の無いプロジェクトに全体トークを作り、スレッド未所属のチャットを紐づける(何度実行しても同じ結果。本文・日時・添付は変更しない)"
  task backfill: :environment do
    before = ProjectChat.where(project_thread_id: nil).count
    result = Business::ProjectThreads::LegacyChatBackfill.call
    after = ProjectChat.where(project_thread_id: nil).count
    without_general = Project.where.not(id: ProjectThread.where(general: true).select(:project_id)).count
    puts "[business_project_threads:backfill] unthreaded_before=#{before} linked=#{result.linked} " \
         "created_general_threads=#{result.created_threads} unthreaded_after=#{after} projects_without_general_thread=#{without_general}"
    # 紐づけ途中で失敗・取り残しがあれば終了コードで分かるようにする(再実行すれば残りだけ処理する)。
    abort "[business_project_threads:backfill] FAILED: unthreaded_after=#{after} projects_without_general_thread=#{without_general}" if after.positive? || without_general.positive?
  end
end

namespace :business_access do
  desc "Business のアクセス制御切り替え前後の確認(読み取り専用。DB は更新しない)"
  task audit: :environment do
    load Rails.root.join("script/business_access_preflight.rb")
    puts BusinessAccessPreflight.run
  end
end
