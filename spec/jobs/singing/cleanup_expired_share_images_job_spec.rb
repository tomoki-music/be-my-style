require "rails_helper"

RSpec.describe Singing::CleanupExpiredShareImagesJob, type: :job do
  it "期限切れのshare imageと添付画像を削除する" do
    expired = create(:singing_share_image, :completed, expires_at: 1.minute.ago)
    active = create(:singing_share_image, :completed, expires_at: 1.day.from_now)
    expired_blob_id = expired.image.blob_id
    active_blob_id = active.image.blob_id

    expect do
      described_class.perform_now
    end.to change(SingingShareImage, :count).by(-1)

    expect(SingingShareImage.exists?(expired.id)).to eq(false)
    expect(ActiveStorage::Blob.exists?(expired_blob_id)).to eq(false)
    expect(SingingShareImage.exists?(active.id)).to eq(true)
    expect(ActiveStorage::Blob.exists?(active_blob_id)).to eq(true)
  end
end
