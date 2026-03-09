admin = Admin.find_or_create_by!(email: 'i.tomoki0218@gmail.com') do |a|
  a.password = 'password'
end