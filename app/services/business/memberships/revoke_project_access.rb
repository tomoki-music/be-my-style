module Business
  module Memberships
    # プロジェクトの参加資格を外す(本人の退出 / 管理者のアクセス停止)。
    # suspend: true のときはアクセス停止を記録し、自動承認でも再参加できないようにする。
    class RevokeProjectAccess
      def self.call(project:, customer:, suspend: false, actor: nil)
        new(project, customer, suspend, actor).call
      end

      def initialize(project, customer, suspend, actor)
        @project = project
        @customer = customer
        @suspend = suspend
        @actor = actor
      end

      def call
        @project.with_lock do
          ProjectMember.where(project_id: @project.id, customer_id: @customer.id).destroy_all
          ProjectJoinRequest.where(project_id: @project.id, customer_id: @customer.id).destroy_all

          if @suspend && !@customer.business_project_suspended?(@project)
            ProjectAccessSuspension.create!(project: @project, customer: @customer, suspended_by: @actor)
          end
        end
        true
      end
    end
  end
end
