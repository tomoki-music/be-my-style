music = Domain.find_by!(name: "music")
business = Domain.find_by!(name: "business")
seed_member = Customer.find_by(id: 1)

def ensure_seed_membership!(community, customer)
  return if community.blank? || customer.blank?

  CommunityCustomer.find_or_create_by!(community: community, customer: customer)

  chat_room_customer = ChatRoomCustomer.find_or_create_by!(community: community, customer: customer) do |crc|
    crc.chat_room = community.chat_rooms.first || ChatRoom.create!
  end

  if chat_room_customer.chat_room.blank?
    chat_room_customer.update!(chat_room: community.chat_rooms.first || ChatRoom.create!)
  end

  community.owner.tap do |owner|
    next if owner.blank?
    CommunityCustomer.find_or_create_by!(community: community, customer: owner)

    owner_chat_room_customer = ChatRoomCustomer.find_or_create_by!(community: community, customer: owner) do |crc|
      crc.chat_room = chat_room_customer.chat_room
    end

    if owner_chat_room_customer.chat_room_id != chat_room_customer.chat_room_id
      owner_chat_room_customer.update!(chat_room: chat_room_customer.chat_room)
    end
  end
end

mmm = Community.find_or_create_by!(name: '埼玉音楽人サークルMMM') do |c|
  c.owner_id = Customer.find_by!(email: 'i.tomoki0218@gmail.com').id
  c.domain_id = music.id
  c.activity_stance = :mypace
  c.prefecture_id = 12
  c.introduction = '初心者から経験者まで、安心して参加できる音楽コミュニティ🎵'
end
ensure_seed_membership!(mmm, seed_member)

mmm = Community.find_or_create_by!(name: 'LifeWithSinging') do |c|
  c.owner_id = Customer.find_by!(email: 'i.tomoki0218+tomusic@gmail.com').id
  c.domain_id = business.id
  c.introduction = '歌を学ぶコミュニティです🎵'
end
ensure_seed_membership!(mmm, seed_member)

Community.find_each do |community|
  ensure_seed_membership!(community, seed_member)
end
