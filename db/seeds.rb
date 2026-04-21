# ===== 本番でも流すマスター =====
load Rails.root.join('db/seeds/master/domains.rb')
load Rails.root.join('db/seeds/master/parts.rb')
load Rails.root.join('db/seeds/master/genres.rb')
# prefectures は ActiveHash 想定なので読み込まない

# ===== 開発環境のみ =====
if Rails.env.development?
  load Rails.root.join('db/seeds/users.rb')
  load Rails.root.join('db/seeds/admins.rb')
  load Rails.root.join('db/seeds/communities.rb')
  load Rails.root.join('db/seeds/learning.rb')
end

# ActiveAdminは現在未使用
# AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development?
