module Business
  module ProjectThreads
    # デプロイ中(マイグレーション後〜Puma 再起動前)に旧コードが残したデータを補う。
    #   - 「全体トーク」が無いプロジェクト(旧コードで作成)には全体トークを作る。
    #   - スレッド未所属のプロジェクトチャット(旧コードで投稿)を、そのプロジェクトの全体トークへ紐づける。
    # 何度実行しても結果は同じ。本文・投稿者・日時・添付は書き換えない(更新するのは project_thread_id だけ)。
    #
    # デプロイ後の手動実行(rails business_project_threads:backfill)に頼らないよう、プロジェクト内部の画面を
    # 開いたときにも project: 指定で呼ぶ(補う必要が無ければ問い合わせ2回で終わる)。
    class LegacyChatBackfill
      Result = Struct.new(:linked, :created_threads, keyword_init: true)

      def self.call(project: nil)
        new(project).call
      end

      # 画面表示から呼ぶ用。失敗しても画面は表示し(呼び出し側で利用者へ再読み込みを案内する)、ログで検知する。
      # 失敗時はトランザクションごと巻き戻るため、投稿・添付は変更されない。
      def self.call_safely(project:)
        call(project: project)
        true
      rescue StandardError => e
        Rails.logger.error("[Business::ProjectThreads::LegacyChatBackfill] failed project_id=#{project.id} #{e.class}: #{e.message}")
        false
      end

      def initialize(project)
        @project = project
      end

      def call
        result = Result.new(linked: 0, created_threads: 0)
        Project.where(id: target_project_ids).find_each { |project| repair(project, result) }
        result
      end

      private

      def target_project_ids
        unthreaded = ProjectChat.where(project_thread_id: nil)
        without_general = Project.where.not(id: ProjectThread.where(general: true).select(:project_id))
        if @project
          unthreaded = unthreaded.where(project_id: @project.id)
          without_general = without_general.where(id: @project.id)
        end

        (unthreaded.distinct.pluck(:project_id) + without_general.pluck(:id)).uniq
      end

      # スレッドの削除・同じ処理の同時実行とプロジェクト行のロックで直列化する。
      # 全体トークの二重作成は (project_id, general) の一意制約でも防ぐ。
      def repair(project, result)
        project.with_lock do
          existed = ProjectThread.default_for(project).present?
          thread = ProjectThread.general_for!(project)
          result.created_threads += 1 unless existed

          chats = project.project_chats.where(project_thread_id: nil)
          latest = chats.maximum(:created_at)
          next if latest.nil?

          result.linked += chats.update_all(project_thread_id: thread.id)
          thread.update_column(:last_posted_at, latest) if latest > thread.last_posted_at
        end
      end
    end
  end
end
