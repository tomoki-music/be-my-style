class AddRichContentToBusinessChats < ActiveRecord::Migration[6.1]
  def change
    # Business のコミュニティ タイムライン(community_posts) / プロジェクト チャット(project_chats) に
    # スタンプと「保存時の書式」を持たせる。既存行は content_format=0(legacy) のまま、
    # 投稿当時と同じ表示方式で描画する。添付は ActiveStorage を使うためカラム追加は不要。
    add_column :community_posts, :stamp_type, :string
    add_column :community_posts, :content_format, :integer, default: 0, null: false
    add_column :project_chats, :stamp_type, :string
    add_column :project_chats, :content_format, :integer, default: 0, null: false
  end
end
