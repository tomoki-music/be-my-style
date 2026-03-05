mmm = Community.find_or_create_by!(name: '埼玉音楽人サークルMMM') do |c|
  c.owner_id = Customer.find_by!(email: 'i.tomoki0218@gmail.com').id
  c.activity_stance = :mypace
  c.prefecture_id = 12
  c.introduction = '初心者から経験者まで、安心して参加できる音楽コミュニティ🎵'
end