music = Domain.find_by!(name: "music")
business = Domain.find_by!(name: "business")

mmm = Community.find_or_create_by!(name: '埼玉音楽人サークルMMM') do |c|
  c.owner_id = Customer.find_by!(email: 'i.tomoki0218@gmail.com').id
  c.domain_id = music.id
  c.activity_stance = :mypace
  c.prefecture_id = 12
  c.introduction = '初心者から経験者まで、安心して参加できる音楽コミュニティ🎵'
end

mmm = Community.find_or_create_by!(name: 'LifeWithSinging') do |c|
  c.owner_id = Customer.find_by!(email: 'i.tomoki0218+tomusic@gmail.com').id
  c.domain_id = business.id
  c.introduction = '歌を学ぶコミュニティです🎵'
end