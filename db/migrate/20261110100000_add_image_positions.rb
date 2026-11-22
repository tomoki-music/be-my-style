require_relative "../../lib/migration_lock_wait_timeout"

class AddImagePositions < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # 画像の表示位置(0〜100%)を元画像とは別に持つ。NULL は「未調整」で、これまでどおり中央基準で表示する。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  COLUMNS = {
    customers: :profile_image,
    communities: :community_image,
    projects: :project_image
  }.freeze

  def up
    COLUMNS.each do |table, attachment|
      %w[x y].each do |axis|
        column = :"#{attachment}_position_#{axis}"
        add_column table, column, :decimal, precision: 5, scale: 2 unless column_exists?(table, column)
      end
    end
  end

  def down
    COLUMNS.each do |table, attachment|
      %w[x y].each do |axis|
        column = :"#{attachment}_position_#{axis}"
        remove_column table, column if column_exists?(table, column)
      end
    end
  end
end
