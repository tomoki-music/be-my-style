users = Customer.all.to_a
users.each do |user|
  users.sample(2).each do |other|
    next if user == other
    user.follow(other.id) unless user.following?(other)
  end
end