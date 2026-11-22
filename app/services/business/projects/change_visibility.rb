module Business
  module Projects
    # 確認画面を通した公開範囲の変更(プライベートへの変更・プライベートからの変更)。権限の確認は呼び出し側で行う。
    #
    #   プライベートへ : 既存メンバーの参加は残す。承認待ちの参加申請は取り消す(招待以外で参加できる経路を残さない)。
    #   プライベートから : 招待リンクをすべて無効化する。親コミュニティに参加していないメンバーは、行は残るが閲覧できなくなる
    #                      (通常・限定公開の参加条件 = 親コミュニティの参加者)。
    #
    # 戻り値: Result(changed:, cancelled_request_count:, revoked_link_count:)
    class ChangeVisibility
      Result = Struct.new(:changed, :cancelled_request_count, :revoked_link_count, keyword_init: true)

      def self.call(project:, visibility:, now: Time.current)
        new(project, visibility, now).call
      end

      def initialize(project, visibility, now)
        @project = project
        @visibility = visibility.to_s
        @now = now
      end

      def call
        raise ArgumentError, "unknown visibility" unless Project.visibilities.key?(@visibility)

        @project.with_lock do
          next Result.new(changed: false, cancelled_request_count: 0, revoked_link_count: 0) if @project.visibility == @visibility

          cancelled = 0
          revoked = 0
          if @visibility == "private"
            cancelled = @project.project_join_requests.destroy_all.size
          elsif @project.visibility_private?
            revoked = ProjectInvitationLink.revoke_all!(@project, now: @now)
          end

          @project.update!(visibility: @visibility)
          Result.new(changed: true, cancelled_request_count: cancelled, revoked_link_count: revoked)
        end
      end
    end
  end
end
