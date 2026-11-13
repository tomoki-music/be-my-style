module Customers
  module Withdrawal
    # 退会した会員のファイルを外部ストレージから消す(プロフィール画像・歌声診断の音声・共有画像・振り返り動画)。
    # 退会の確定(DB のコミット)の後に呼ぶ。1件の失敗でほかの削除を止めず、失敗数を返す。
    # 何度呼んでも安全(削除済みのものは対象にならない)。失敗分は rake customers:withdrawal:purge_files で再実行する。
    # 共有画像・振り返り動画の行は、ほかの集計・履歴から参照されるため残す(公開ページは退会者なら表示しない)。
    # 投稿(活動報告・チャット)に添付したファイルは、ほかの人との共有履歴として残す。
    class PurgeFiles
      LOG_TAG = "[Customers::Withdrawal::PurgeFiles]".freeze

      def self.call(customer)
        new(customer).call
      end

      def initialize(customer)
        @customer = customer
        @failures = 0
      end

      def call
        return 0 unless @customer.withdrawn?

        purge(@customer.profile_image)
        @customer.singing_diagnoses.with_attached_audio_file.find_each { |diagnosis| purge(diagnosis.audio_file) }
        @customer.singing_share_images.with_attached_image.find_each { |share_image| purge(share_image.image) }
        @customer.singing_generated_recap_movies.with_attached_video_file.find_each { |movie| purge(movie.video_file) }
        @failures
      end

      private

      def purge(attachment)
        return unless attachment.attached?

        attachment.purge
      rescue StandardError => e
        @failures += 1
        # ファイル名・URL は個人情報を含みうるため出さない。
        Rails.logger.error("#{LOG_TAG} 削除に失敗しました customer_id=#{@customer.id} #{e.class}")
      end
    end
  end
end
