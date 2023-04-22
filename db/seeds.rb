# create_table "customers", charset: "utf8mb3", force: :cascade do |t|
#     t.string "email", default: "", null: false
#     t.string "encrypted_password", default: "", null: false
#     t.string "reset_password_token"
#     t.datetime "reset_password_sent_at"
#     t.datetime "remember_created_at"
#     t.string "name"
#     t.integer "postal_code"
#     t.string "address"
#     t.string "tell"
#     t.boolean "is_deleted", default: false, null: false
#     t.datetime "created_at", precision: 6, null: false
#     t.datetime "updated_at", precision: 6, null: false
#     t.text "introduction"
#     t.integer "part"
#     t.integer "sex"
#     t.date "birthday"
#     t.string "favorite_artist"
#     t.text "url"
#     t.index ["email"], name: "index_customers_on_email", unique: true
#     t.index ["reset_password_token"], name: "index_customers_on_reset_password_token", unique: true
#   end

# class Prefecture < ActiveHash::Base
#     self.data = [
#       { id: 1, name: '---' }, { id: 2, name: '北海道' }, { id: 3, name: '青森県' },
#       { id: 4, name: '岩手県' }, { id: 5, name: '宮城県' }, { id: 6, name: '秋田県' }, 
#       { id: 7, name: '山形県' }, { id: 8, name: '福島県' }, { id: 9, name: '茨城県' },
#       { id: 10, name: '栃木県' }, { id: 11, name: '群馬県' }, { id: 12, name: '埼玉県' },
#       { id: 13, name: '千葉県' }, { id: 14, name: '東京都' }, { id: 15, name: '神奈川県' },
#       { id: 16, name: '新潟県' }, { id: 17, name: '富山県' }, { id: 18, name: '石川県' },
#       { id: 19, name: '福井県' }, { id: 20, name: '山梨県' }, { id: 21, name: '長野県' },
#       { id: 22, name: '岐阜県' }, { id: 23, name: '静岡県' }, { id: 24, name: '愛知県' }, 
#       { id: 25, name: '三重県' }, { id: 26, name: '滋賀県' }, { id: 27, name: '京都府' }, 
#       { id: 28, name: '大阪府' }, { id: 29, name: '兵庫県' }, { id: 30, name: '奈良県' }, 
#       { id: 31, name: '和歌山県' }, { id: 32, name: '鳥取県' }, { id: 33, name: '島根県' }, 
#       { id: 34, name: '岡山県' }, { id: 35, name: '広島県' }, { id: 36, name: '山口県' }, 
#       { id: 37, name: '徳島県' }, { id: 38, name: '香川県' }, { id: 39, name: '愛媛県' }, 
#       { id: 40, name: '高知県' }, { id: 41, name: '福岡県' }, { id: 42, name: '佐賀県' }, 
#       { id: 43, name: '長崎県' }, { id: 44, name: '熊本県' }, { id: 45, name: '大分県' }, 
#       { id: 46, name: '宮崎県' }, { id: 47, name: '鹿児島県' }, { id: 48, name: '沖縄県' }
#   ]

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

tomoki = Customer.create!(
    name: 'tomoki',
    email: 'i.tomoki0218@gmail.com',
    password: 'tomoki1969',
    sex: :male,
    prefecture_id: 12,
    introduction: '歌で皆んなに元気を届けます！',
    )

tomoki.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/tomoki.jpg')),filename: 'tomoki.jpg')
tomoki.parts << vocal
tomoki.parts << guitar
tomoki.parts << composer

tomusic = Customer.create!(
    name: 'tomusic',
    email: 'tomusic@gmail.com',
    password: 'tomusic1969',
    sex: :male,
    prefecture_id: 12,
    introduction: 'みんなで楽しめるイベントを企画します！',
    )

tomusic.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/tomusic.jpg')),filename: 'tomusic.jpg')
tomusic.parts << bass
tomusic.parts << drums

mayu = Customer.create!(
    name: 'mayu',
    email: 'mayu@gmail.com',
    password: 'mayu1969',
    sex: :female,
    prefecture_id: 15,
    introduction: 'とにかく歌う事が大好き！ぜひ、バンドで歌わせてください！',
    )

mayu.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/mayu.jpg')),filename: 'mayu.jpg')
mayu.parts << vocal

luka = Customer.create!(
    name: 'luka',
    email: 'luka@gmail.com',
    password: 'luka1969',
    sex: :female,
    prefecture_id: 13,
    introduction: '音楽やっている時が一番幸せ！ブルーノート勉強中。',
    )

luka.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/luka.jpg')),filename: 'luka.jpg')
luka.parts << guitar

hatsune = Customer.create!(
    name: 'hatsune',
    email: 'hatsune@gmail.com',
    password: 'hatsune1969',
    sex: :male,
    prefecture_id: 14,
    introduction: '心に刺さるメロディラインと、心に残る作詞を心がけてます！',
    )

hatsune.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/hatsune.jpg')),filename: 'hatsune.jpg')
hatsune.parts << composer
hatsune.parts << guitar


john = Customer.create!(
    name: 'john',
    email: 'john@gmail.com',
    password: 'john1969',
    sex: :male,
    prefecture_id: 41,
    introduction: '音楽は皆んなにとって平等で、誰も否定したりしない。',
    )

john.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/john.jpg')),filename: 'john.jpg')
john.parts << vocal
john.parts << guitar

paul = Customer.create!(
    name: 'paul',
    email: 'paul@gmail.com',
    password: 'paul1969',
    sex: :male,
    prefecture_id: 47,
    introduction: 'いつまでも、おじさんになっても音楽やってたいな〜！',
    )

paul.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/paul.jpg')),filename: 'paul.jpg')
paul.parts << bass
paul.parts << vocal

george = Customer.create!(
    name: 'george',
    email: 'george@gmail.com',
    password: 'george1969',
    sex: :male,
    prefecture_id: 2,
    introduction: 'あの舞台は忘れられないな。またみんなでLIVEやりたいな。',
    )

george.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/george.jpg')),filename: 'george.jpg')
george.parts << guitar

ringo = Customer.create!(
    name: 'ringo',
    email: 'ringo@gmail.com',
    password: 'ringo1969',
    sex: :male,
    prefecture_id: 6,
    introduction: 'リズムは人類の根源！さぁドラムに皆んな乗ってこい！',
    )

ringo.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/ringo.jpg')),filename: 'ringo.jpg')
ringo.parts << drums

takuro = Customer.create!(
    name: 'takuro',
    email: 'takuro@gmail.com',
    password: 'takuro1969',
    sex: :male,
    prefecture_id: 1,
    introduction: 'Love&PEACE。最高の音楽にはいつも愛と平和がある。',
    )

takuro.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/takuro.jpg')),filename: 'takuro.jpg')
takuro.parts << guitar
takuro.parts << composer

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
