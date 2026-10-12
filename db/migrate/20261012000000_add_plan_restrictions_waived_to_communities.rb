class AddPlanRestrictionsWaivedToCommunities < ActiveRecord::Migration[6.1]
  def change
    # Business コミュニティ単位の「有料プラン制限を解除する（無料お試し）」設定。
    # 既存コミュニティは OFF のまま。課金・契約情報には一切触れない判定用フラグ。
    add_column :communities, :plan_restrictions_waived, :boolean, default: false, null: false
  end
end
