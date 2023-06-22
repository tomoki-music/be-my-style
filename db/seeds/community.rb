tomoki = Customer.find(1)
tomusic = Customer.find(2)
mayu = Customer.find(3)
luka = Customer.find(4)
hatsune = Customer.find(5)
john = Customer.find(6)
paul = Customer.find(7)
george = Customer.find(8)
ringo = Customer.find(9)
takuro = Customer.find(10)

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

mmm.genres << [pops, rock, blues, anime_songs, visual]
mmm.community_image.attach(io: File.open(Rails.root.join('app/assets/images/mmm.jpg')),filename: 'mmm.jpg')
mmm.customers << [tomusic, mayu, luka, hatsune, takuro, john, paul, george, ringo]

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

enjoy_music.genres << [pops, rock, blues, anime_songs, visual]
enjoy_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/enjoy_music.jpg')),filename: 'enjoy_music.jpg')
enjoy_music.customers << [tomusic, mayu, luka, hatsune, takuro]

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

western_music.genres << [pops, rock, blues, hard_rock, metal]
western_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/western_music.jpg')),filename: 'western_music.jpg')
western_music.customers << [john, paul, george, ringo]

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

free_music.genres << [pops, rock, blues, hard_rock, jazz]
free_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/free_music.jpg')),filename: 'free_music.jpg')
free_music.customers << [tomusic, john, paul, george, ringo]

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

beginner.genres << [pops, rock]
beginner.community_image.attach(io: File.open(Rails.root.join('app/assets/images/beginner.jpg')),filename: 'beginner.jpg')
beginner.customers << [tomusic, mayu, luka]

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

study_music.genres << [pops, rock]
study_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/study_music.jpg')),filename: 'study_music.jpg')
study_music.customers << [tomusic, mayu, luka, hatsune, takuro, john, paul]

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

acoustic_music.genres << [pops, rock]
acoustic_music.community_image.attach(io: File.open(Rails.root.join('app/assets/images/sherry.jpg')),filename: 'sherry.jpg')
acoustic_music.customers << [tomusic, mayu, luka, takuro]