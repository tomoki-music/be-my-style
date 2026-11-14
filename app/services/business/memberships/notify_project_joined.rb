module Business
  module Memberships
    # プロジェクトへの参加を、内部を閲覧できる人(Project#accessible_customers)へ画面内の通知とメールで知らせる。
    # 「参加する」(自動承認)と招待リンクからの参加で同じ宛先・同じ設定判定にする。
    class NotifyProjectJoined
      def self.call(project:, actor:)
        project.accessible_customers.includes(:business_notification_setting).where.not(id: actor.id).find_each do |customer|
          customer.business_notification_project_joined(actor, project)
          next unless customer.business_email_notifications_enabled?

          CustomerMailer.with(
            ac_customer: actor,
            ps_customer: customer,
            project: project
          ).business_project_joined_mail.deliver_later
        end
      end
    end
  end
end
