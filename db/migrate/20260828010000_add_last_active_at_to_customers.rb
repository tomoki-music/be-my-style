class AddLastActiveAtToCustomers < ActiveRecord::Migration[6.1]
  # ログイン継続中の利用日時を記録するカラム。
  # Devise trackable の current_sign_in_at と同じ素の datetime 精度に合わせ、
  # 既存ユーザーのバックフィルや index は行わない（本番規模が小さく不要なため）。
  # 現在の Customer モデル（バリデーション/コールバック/デフォルト値）に依存させないよう
  # 単純な add_column / remove_column だけで構成する。
  def up
    add_column :customers, :last_active_at, :datetime
  end

  def down
    remove_column :customers, :last_active_at
  end
end
