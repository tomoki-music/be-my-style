Part.create!([
    { name: 'ボーカル' },
    { name: 'ギター' },
    { name: 'ベース'},
    { name: 'ドラム'},
    { name: 'ピアノ・キーボード'},
    { name: '作詞・作曲・アレンジャー'},
    { name: 'パーカッション'},
    { name: '管楽器'},
    { name: '弦楽器'},
    { name: 'ダンサー'},
    { name: 'その他'},
])

vocal = Part.find(1)
guitar = Part.find(2)
bass = Part.find(3)
drums = Part.find(4)
keyboard = Part.find(5)
composer = Part.find(6)
percussion = Part.find(7)
strings = Part.find(8)
winds = Part.find(9)
dancer = Part.find(10)
others = Part.find(11)

Genre.create!([
    { name: 'ポップス' },
    { name: 'ロック' },
    { name: 'ハードロック・ヘビメタ'},
    { name: 'パンク・メロコア'},
    { name: 'ハードコア'},
    { name: 'メタル'},
    { name: 'ヴィジュアル系'},
    { name: 'ファンク・ブルース'},
    { name: 'ジャズ・フュージョン'},
    { name: 'カントリー・フォーク'},
    { name: 'スカ・ロカビリー'},
    { name: 'ソウル・R&B'},
    { name: 'ゴスペル・アカペラ'},
    { name: 'ボサノバ・ラテン'},
    { name: 'クラシック'},
    { name: 'ヒップホップ・レゲェ'},
    { name: 'ハウス・テクノ'},
    { name: 'アニソン・ボカロ'},
    { name: 'その他'},
])

pops = Genre.find(1)
rock = Genre.find(2)
hard_rock = Genre.find(3)
punk = Genre.find(4)
hard_core = Genre.find(5)
metal = Genre.find(6)
visual = Genre.find(7)
blues = Genre.find(8)
jazz = Genre.find(9)
folk = Genre.find(10)
rockabilly = Genre.find(11)
soul = Genre.find(12)
gospel = Genre.find(13)
bossa_nova = Genre.find(14)
classic = Genre.find(15)
hiphop = Genre.find(16)
techno = Genre.find(17)
anime_songs = Genre.find(18)
genre_others = Genre.find(19)

tomoki = Customer.create!(
    name: 'tomoki',
    email: 'i.tomoki0218@gmail.com',
    password: 'tomoki1969',
    sex: :male,
    activity_stance: :mypace,
    prefecture_id: 12,
    favorite_artist1: 'GLAY',
    favorite_artist2: 'BEATLES',
    favorite_artist3: 'L\'Arc〜en〜Ciel',
    favorite_artist4: 'LUNA SEA',
    favorite_artist5: 'ELLEGARDEN',
    url: 'https://soundcloud.com/end-of-dream1969',
    introduction: '歌で皆んなに元気を届けます！',
    )

tomoki.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/tomoki.jpg')),filename: 'tomoki.jpg')
tomoki.parts << [vocal, guitar, composer]
tomoki.genres << [pops, rock, blues, jazz, anime_songs, visual]
(1..10).each do |id|
    tomoki.follow(id)
end

tomusic = Customer.create!(
    name: 'tomusic',
    email: 'tomusic@gmail.com',
    password: 'tomusic1969',
    sex: :male,
    activity_stance: :mypace,
    favorite_artist1: 'Led Zeppelin',
    favorite_artist2: 'Deep Purple',
    favorite_artist3: 'Bon Jovi',
    favorite_artist4: 'ONE OK ROCK',
    favorite_artist5: 'ELLEGARDEN',
    prefecture_id: 12,
    introduction: 'みんなで楽しめるイベントを企画します！',
    )

tomusic.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/tomusic.jpg')),filename: 'tomusic.jpg')
tomusic.parts << [bass, drums]
tomusic.genres << [pops, rock, jazz, blues, folk, anime_songs]
(1..10).each do |id|
    tomusic.follow(id)
end

mayu = Customer.create!(
    name: 'mayu',
    email: 'mayu@gmail.com',
    password: 'mayu1969',
    sex: :female,
    activity_stance: :beginer,
    favorite_artist1: '相川七瀬',
    favorite_artist2: '中島美嘉',
    favorite_artist3: 'Avril Ramona Lavigne',
    favorite_artist4: 'YOASOBI',
    favorite_artist5: 'LiSA',
    prefecture_id: 15,
    introduction: 'とにかく歌う事が大好き！ぜひ、バンドで歌わせてください！',
    )

mayu.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/mayu.jpg')),filename: 'mayu.jpg')
mayu.parts << [vocal, dancer, strings]
mayu.genres << [pops, rock, classic, gospel, anime_songs]
(1..10).each do |id|
    mayu.follow(id)
end

luka = Customer.create!(
    name: 'luka',
    email: 'luka@gmail.com',
    password: 'luka1969',
    sex: :female,
    activity_stance: :mypace,
    favorite_artist1: 'L\'Arc〜en〜Ciel',
    favorite_artist2: 'IRON MAIDEN',
    favorite_artist3: 'Ozzy Osbourne',
    favorite_artist4: 'Vaundy',
    favorite_artist5: 'LiSA',
    prefecture_id: 13,
    introduction: '音楽やっている時が一番幸せ！ブルーノート勉強中。',
    )

luka.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/luka.jpg')),filename: 'luka.jpg')
luka.parts << [guitar, bass]
luka.genres << [rock, blues, metal, jazz, soul, anime_songs,visual]
(1..10).each do |id|
    luka.follow(id)
end

hatsune = Customer.create!(
    name: 'hatsune',
    email: 'hatsune@gmail.com',
    password: 'hatsune1969',
    sex: :male,
    activity_stance: :tightly,
    favorite_artist1: 'Metallica',
    favorite_artist2: 'Nirvana',
    favorite_artist3: 'Ozzy Osbourne',
    favorite_artist4: 'BLACK SABBATH',
    favorite_artist5: 'Deep Purple',
    prefecture_id: 14,
    introduction: '心に刺さるメロディラインと、心に残る作詞を心がけてます！',
    )

hatsune.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/hatsune.jpg')),filename: 'hatsune.jpg')
hatsune.parts << [composer, guitar, vocal]
hatsune.genres << [rock, hard_rock, hard_core, metal, anime_songs, techno]
(1..10).each do |id|
    hatsune.follow(id)
end

john = Customer.create!(
    name: 'john',
    email: 'john@gmail.com',
    password: 'john1969',
    sex: :male,
    activity_stance: :mypace,
    favorite_artist1: 'BEATLES',
    favorite_artist2: 'Nirvana',
    favorite_artist3: 'ERIC CLAPTON',
    favorite_artist4: 'Led Zeppelin',
    favorite_artist5: 'Jimi Hendrix',
    prefecture_id: 41,
    introduction: '音楽は皆んなにとって平等で、誰も否定したりしない。',
    )

john.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/john.jpg')),filename: 'john.jpg')
john.parts << [vocal, guitar, composer, strings]
john.genres << [rock, blues, classic, folk, rockabilly, jazz]
(1..10).each do |id|
    john.follow(id)
end

paul = Customer.create!(
    name: 'paul',
    email: 'paul@gmail.com',
    password: 'paul1969',
    sex: :male,
    activity_stance: :tightly,
    favorite_artist1: 'BEATLES',
    favorite_artist2: 'Brian May',
    favorite_artist3: 'ERIC CLAPTON',
    favorite_artist4: 'Kurt Donald Cobain',
    favorite_artist5: 'Jimi Hendrix',
    prefecture_id: 47,
    introduction: 'いつまでも、おじさんになっても音楽やってたいな〜！',
    )

paul.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/paul.jpg')),filename: 'paul.jpg')
paul.parts << [bass, vocal, composer]
paul.genres << [rock, blues, folk, rockabilly, hard_rock]
(1..10).each do |id|
    paul.follow(id)
end

george = Customer.create!(
    name: 'george',
    email: 'george@gmail.com',
    password: 'george1969',
    sex: :male,
    activity_stance: :tightly,
    favorite_artist1: 'BEATLES',
    favorite_artist2: '布袋寅泰',
    favorite_artist3: 'ERIC CLAPTON',
    favorite_artist4: 'Keith Richard',
    favorite_artist5: 'James Patrick Page',
    prefecture_id: 2,
    introduction: 'あの舞台は忘れられないな。またみんなでLIVEやりたいな。',
    )

george.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/george.jpg')),filename: 'george.jpg')
george.parts << [guitar, winds]
george.genres << [rock, blues, folk, rockabilly, hiphop]
(1..10).each do |id|
    george.follow(id)
end

ringo = Customer.create!(
    name: 'ringo',
    email: 'ringo@gmail.com',
    password: 'ringo1969',
    sex: :male,
    activity_stance: :tightly,
    favorite_artist1: 'BEATLES',
    favorite_artist2: 'John Bonham',
    favorite_artist3: 'Keith Moon',
    favorite_artist4: 'Ginger Baker',
    favorite_artist5: 'Neil Peart',
    prefecture_id: 6,
    introduction: 'リズムは人類の根源！さぁドラムに皆んな乗ってこい！',
    )

ringo.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/ringo.jpg')),filename: 'ringo.jpg')
ringo.parts << [drums, others]
ringo.genres << [rock, blues, jazz, metal, classic, hard_core]
(1..10).each do |id|
    ringo.follow(id)
end

takuro = Customer.create!(
    name: 'takuro',
    email: 'takuro@gmail.com',
    password: 'takuro1969',
    sex: :male,
    activity_stance: :mypace,
    favorite_artist1: 'BEATLES',
    favorite_artist2: 'GLAY',
    favorite_artist3: 'John Winston Ono Lennon',
    favorite_artist4: 'オノヨーコ',
    favorite_artist5: 'Jimi Hendrix',
    prefecture_id: 1,
    introduction: 'Love&PEACE。最高の音楽にはいつも愛と平和がある。',
    )

takuro.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/takuro.jpg')),filename: 'takuro.jpg')
takuro.parts << [guitar, composer]
takuro.genres << [pops, rock, hard_rock, blues, folk, rockabilly, classic]
(1..10).each do |id|
    takuro.follow(id)
end

Admin.create!(
    :name => 'tomoki',
    :email => 'i.tomoki0218@gmail.com',
    :password => 'tomoki1969'
    )

Tag.create!([
    { name: '音楽全般' },
    { name: 'ファッション' },
    { name: 'プログラミング'},
    { name: '動画制作'},
    { name: '作詞作曲'},
    { name: 'コピーセッション'},
    { name: 'フリーセッション'},
    { name: '初心者セッション'},
    ])

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
