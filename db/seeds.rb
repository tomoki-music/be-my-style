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
    part: :vocal,
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
    part: :guitar,
    introduction: 'みんなで楽しめるイベントを企画します！',
    )

tomusic.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/tomusic.jpg')),filename: 'tomusic.jpg')
tomusic.parts << bass
tomusic.parts << drums

mayu = Customer.create!(
    name: 'mayu',
    email: 'mayu@gmail.com',
    password: 'mayu1969',
    part: :vocal,
    introduction: 'とにかく歌う事が大好き！ぜひ、バンドで歌わせてください！',
    )

mayu.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/mayu.jpg')),filename: 'mayu.jpg')
mayu.parts << vocal

luka = Customer.create!(
    name: 'luka',
    email: 'luka@gmail.com',
    password: 'luka1969',
    part: :guitar,
    introduction: '音楽やっている時が一番幸せ！ブルーノート勉強中。',
    )

luka.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/luka.jpg')),filename: 'luka.jpg')
luka.parts << guitar

hatsune = Customer.create!(
    name: 'hatsune',
    email: 'hatsune@gmail.com',
    password: 'hatsune1969',
    part: :composer,
    introduction: '心に刺さるメロディラインと、心に残る作詞を心がけてます！',
    )

hatsune.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/hatsune.jpg')),filename: 'hatsune.jpg')
hatsune.parts << composer
hatsune.parts << guitar


john = Customer.create!(
    name: 'john',
    email: 'john@gmail.com',
    password: 'john1969',
    part: :guitar,
    introduction: '音楽は皆んなにとって平等で、誰も否定したりしない。',
    )

john.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/john.jpg')),filename: 'john.jpg')
john.parts << vocal
john.parts << guitar

paul = Customer.create!(
    name: 'paul',
    email: 'paul@gmail.com',
    password: 'paul1969',
    part: :bass,
    introduction: 'いつまでも、おじさんになっても音楽やってたいな〜！',
    )

paul.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/paul.jpg')),filename: 'paul.jpg')
paul.parts << bass
paul.parts << vocal

george = Customer.create!(
    name: 'george',
    email: 'george@gmail.com',
    password: 'george1969',
    part: :guitar,
    introduction: 'あの舞台は忘れられないな。またみんなでLIVEやりたいな。',
    )

george.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/george.jpg')),filename: 'george.jpg')
george.parts << guitar

ringo = Customer.create!(
    name: 'ringo',
    email: 'ringo@gmail.com',
    password: 'ringo1969',
    part: :drums,
    introduction: 'リズムは人類の根源！さぁドラムに皆んな乗ってこい！',
    )

ringo.profile_image.attach(io: File.open(Rails.root.join('app/assets/images/ringo.jpg')),filename: 'ringo.jpg')
ringo.parts << drums

takuro = Customer.create!(
    name: 'takuro',
    email: 'takuro@gmail.com',
    password: 'takuro1969',
    part: :composer,
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
