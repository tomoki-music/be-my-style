module Business
  module SignupInvitations
    # 招待用URL(Business::ShareHelper#business_share_url)が指す詳細画面のパスと、その対象の相互変換・検証。
    # 招待用URLはトークンを持たないため、詳細画面のパスそのものを招待先として扱う。対象はサーバー側で読み直して確かめる。
    module Target
      PATH_PATTERN = %r{\A/business/(communities|projects)/(\d+)\z}.freeze
      TYPES_BY_SEGMENT = { "communities" => "Community", "projects" => "Project" }.freeze

      module_function

      # "/business/communities/12" → ["Community", 12]。招待用URL以外の形(一覧・編集・クエリ付きなど)は nil。
      def parse(path)
        match = PATH_PATTERN.match(path.to_s)
        return unless match

        [TYPES_BY_SEGMENT.fetch(match[1]), match[2].to_i]
      end

      # いまも存在する Business のコミュニティ・プロジェクト。削除済み・Business 以外は nil。
      def find(type, id)
        case type
        when "Community" then business_communities.find_by(id: id)
        when "Project" then Project.where(community_id: business_communities.select(:id)).find_by(id: id)
        end
      end

      def path_for(type, id)
        record = find(type, id)
        record && path_of(record)
      end

      def path_of(record)
        routes = Rails.application.routes.url_helpers
        record.is_a?(Project) ? routes.business_project_path(record) : routes.business_community_path(record)
      end

      # 招待先の詳細画面を開ける(参加・申請の案内を含めて表示できる)か。
      # コミュニティはいつでも開ける。プロジェクトは親コミュニティの参加者でないと開けず、コミュニティの参加案内へ移る
      # (Business::ProjectsController#show)。中身(スレッド・メンバー)を見られるかは詳細画面側の判定に任せる。
      def openable?(customer, record)
        return true if record.is_a?(Community)

        customer.business_community_participant?(record.community)
      end

      def business_communities
        Community.where(domain_id: Domain.where(name: "business").select(:id))
      end
    end
  end
end
