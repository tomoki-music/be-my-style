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

mmm = Community.create!(
  name: '埼玉音楽人サークルMMM',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: '相川七瀬',
  favorite_artist2: '中島美嘉',
  favorite_artist3: 'L\'Arc〜en〜Ciel',
  favorite_artist4: '菅田将暉',
  favorite_artist5: 'ONE OK ROCK',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: '埼玉地域密着型の社会人音楽サークルです🎵初心者から上級者まで、和気藹々をモットーに楽しくセッションしてます♪───Ｏ（≧∇≦）Ｏ────♪',
  owner_id: 1,
  )

chat_room1 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room1.id, community_id: mmm.id)
mmm.genres << [pops, rock, blues, anime_songs, visual]
mmm.community_image.attach(io: File.open(Rails.root.join('app/assets/images/mmm.jpg')),filename: 'mmm.jpg')

enjoy_music = Community.create!(
  name: '【MMM】邦楽コピーセッション',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: '相川七瀬',
  favorite_artist2: '中島美嘉',
  favorite_artist3: 'L\'Arc〜en〜Ciel',
  favorite_artist4: '菅田将暉',
  favorite_artist5: 'ONE OK ROCK',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: '邦楽曲を中心に、メジャーな曲を皆んなでワイワイ演奏しています🎵',
  owner_id: 1,
  )

chat_room2 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room2.id, community_id: enjoy_music.id)
enjoy_music.genres << [pops, rock, blues, anime_songs, visual]
enjoy_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/enjoy_music.jpg')),filename: 'enjoy_music.jpg')

western_music = Community.create!(
  name: '【MMM】洋楽コピーセッション',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: 'Bon Jovi',
  favorite_artist2: 'BLACK SABBATH',
  favorite_artist3: 'JET',
  favorite_artist4: 'IRON MAIDEN',
  favorite_artist5: 'Ozzy Osbourne',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: 'こちらは洋楽曲を中心に、主にハードロックやメタルを選曲してガシガシ演奏しています🎵',
  owner_id: 1,
  )

chat_room3 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room3.id, community_id: western_music.id)
western_music.genres << [pops, rock, blues, hard_rock, metal]
western_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/western_music.jpg')),filename: 'western_music.jpg')

free_music = Community.create!(
  name: '【MMM】フリーセッション',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: 'Autumn Leaves',
  favorite_artist2: 'The Chicken',
  favorite_artist3: 'ルパン三世のテーマ',
  favorite_artist4: '丸の内サディスティック',
  favorite_artist5: 'STAYTUNE',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: 'コード進行やテーマを簡単に決めて、自由に演奏します。音楽は自由🎵',
  owner_id: 1,
  )

chat_room4 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room4.id, community_id: free_music.id)
free_music.genres << [pops, rock, blues, hard_rock, jazz]
free_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/free_music.jpg')),filename: 'free_music.jpg')

beginner = Community.create!(
  name: '【MMM】初心者セッション',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: 'あいみょん',
  favorite_artist2: '菅田将暉',
  favorite_artist3: '家入レオ',
  favorite_artist4: 'ELLEGARDEN',
  favorite_artist5: 'ONE OK ROCK',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: '楽器を始めたばかり...サークルには参加したて...そんな方の為に優しく楽しくセッション🎵',
  owner_id: 1,
  )

chat_room5 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room5.id, community_id: beginner.id)
beginner.genres << [pops, rock]
beginner.community_image.attach(io: File.open(Rails.root.join('app/assets/images/beginner.jpg')),filename: 'beginner.jpg')

study_music = Community.create!(
  name: '【MMM】作詞作曲勉強会',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: '作詞について',
  favorite_artist2: '作曲について',
  favorite_artist3: 'コード進行作曲術',
  favorite_artist4: 'メロディとコード',
  favorite_artist5: 'リズムの遊び方',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: '世界に一つだけの、自分だけの１曲を作ろう！その為の作曲方法を学びます🎵',
  owner_id: 1,
  )

chat_room6 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room6.id, community_id: study_music.id)
study_music.genres << [pops, rock]
study_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/study_music.jpg')),filename: 'study_music.jpg')

acoustic_music = Community.create!(
  name: '【MMM】アコースティックセッション',
  activity_stance: :mypace,
  prefecture_id: 12,
  favorite_artist1: 'あいみょん',
  favorite_artist2: 'Voundy',
  favorite_artist3: '斉藤和義',
  favorite_artist4: 'スピッツ',
  favorite_artist5: 'レミオロメン',
  url: 'https://be-artist-singer-creater.jimdo.com/',
  introduction: 'しっとりと、じっくりと、ゆっくりと🎵音楽を自分のペース味わうアコースティックなセッションです🎵',
  owner_id: 1,
  )

chat_room7 = ChatRoom.create!
ChatRoomCustomer.create!(customer_id: tomoki.id, chat_room_id: chat_room7.id, community_id: acoustic_music.id)
acoustic_music.genres << [pops, rock]
acoustic_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/sherry.jpg')),filename: 'sherry.jpg')
