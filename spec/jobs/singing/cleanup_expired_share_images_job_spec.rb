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

  it "古いfailed状態と添付欠損のcompletedもcleanup対象にし、件数をloggingする" do
    logger = instance_spy(ActiveSupport::Logger)
    allow(Rails).to receive(:logger).and_return(logger)

    failed = create(:singing_share_image, status: :failed, updated_at: 2.days.ago)
    missing_attachment = create(:singing_share_image, :completed, expires_at: 1.day.from_now)
    missing_attachment.image.purge

    result = described_class.perform_now

    expect(SingingShareImage.exists?(failed.id)).to eq(false)
    expect(SingingShareImage.exists?(missing_attachment.id)).to eq(false)
    expect(result).to include(
      target_count: 2,
      destroy_count: 2,
      error_count: 0
    )
    expect(logger).to have_received(:info).with(include("start", "target_count"))
    expect(logger).to have_received(:info).with(include("finish", "destroy_count"))
  end

  it "share image配下の古いorphan blobを削除する" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("PNG"),
      filename: "orphan.png",
      content_type: "image/png",
      key: "singing/share_images/yearly-growth/orphan.png",
      identify: false
    )
    blob.update!(created_at: 2.days.ago)

    expect do
      described_class.perform_now
    end.to change(ActiveStorage::Blob, :count).by(-1)
  end
end
