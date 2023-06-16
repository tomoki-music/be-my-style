mmm = Community.create!(
  name: '埼玉音楽人サークルMMM',
  introduction: '埼玉地域密着型の社会人音楽サークルです🎵初心者から上級者まで、和気藹々をモットーに楽しくセッションしてます♪───Ｏ（≧∇≦）Ｏ────♪',
  owner_id: 1,
  )

mmm.community_image.attach(io: File.open(Rails.root.join('app/assets/images/mmm.jpg')),filename: 'mmm.jpg')