# db/seeds/users.rb
tomoki = Customer.find_or_create_by!(email: 'i.tomoki0218@gmail.com') do |c|
  c.name = 'トモキ'
  c.password = 'password'
  c.sex = :male
  c.activity_stance = :tightly
  c.prefecture_id = 12
  c.introduction = '音楽で人と人が繋がる場を作りたい'
end

quiet = Customer.find_or_create_by!(email: 'quiet.user@gmail.com') do |c|
  c.name = 'しずか'
  c.password = 'password'
  c.activity_stance = :mypace
  c.prefecture_id = 11
  c.introduction = '見る専だけど、たまに参加します'
end

newbie = Customer.find_or_create_by!(email: 'newbie@gmail.com') do |c|
  c.name = 'はじめ'
  c.password = 'password'
  c.activity_stance = :beginner
  c.prefecture_id = 13
  c.introduction = '最近音楽を始めました！'
end

vocal    = Part.find_by!(name: 'ボーカル')
guitar   = Part.find_by!(name: 'ギター')
composer = Part.find_by!(name: '作詞・作曲・アレンジャー')

pops  = Genre.find_by!(name: 'ポップス')
rock  = Genre.find_by!(name: 'ロック')
jazz  = Genre.find_by!(name: 'ジャズ・フュージョン')

tomoki.parts  = (tomoki.parts + [vocal, guitar, composer]).uniq
tomoki.genres = (tomoki.genres + [pops, rock]).uniq

quiet.parts   = (quiet.parts + [vocal]).uniq
quiet.genres  = (quiet.genres + [jazz]).uniq

# 3人に音楽ドメイン付与
[tomoki, quiet, newbie].each do |customer|
  customer.domains << music unless customer.domains.include?(music)
end