Customer.create!([
    { name: 'tomoki', email: 'i.tomoki0218@gmail.com', password: 'tomoki1969' },
    { name: 'tomusic', email: 'example@gmail.com', password: 'tomusic' },
    { name: 'teru', email: 'teru@gmail.com', password: 'teru1969' },
    { name: 'takuro', email: 'takuro@gmail.com', password: 'takuro1969' },
    { name: 'hisashi', email: 'hisashi@gmail.com', password: 'hisashi1969' },
    { name: 'jiro', email: 'jiro@gmail.com', password: 'jiro1969' },
    ])

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
