require "rails_helper"

RSpec.describe Chat::LinkDetector, type: :service do
  def detect(content)
    described_class.call(content)
  end

  it "通常のwatch URLから動画IDを抽出すること" do
    result = detect("見て https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expect(result.size).to eq 1
    expect(result.first.provider).to eq :youtube
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
    expect(result.first.url).to eq "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  end

  it "youtu.be短縮URLから動画IDを抽出すること" do
    result = detect("https://youtu.be/dQw4w9WgXcQ")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "Shorts URLから動画IDを抽出すること" do
    result = detect("https://www.youtube.com/shorts/dQw4w9WgXcQ")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "Live URLから動画IDを抽出すること" do
    result = detect("https://www.youtube.com/live/dQw4w9WgXcQ")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "クエリパラメータ・フラグメントを無視して正規化すること" do
    result = detect("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s&list=PLxxxx#foo")
    expect(result.first.url).to eq "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  end

  it "Markdownリンク記法内のURLも抽出すること" do
    result = detect("[この曲](https://www.youtube.com/watch?v=dQw4w9WgXcQ)最高")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "複数の異なるURLをすべて抽出すること" do
    result = detect(<<~TEXT)
      https://www.youtube.com/watch?v=aaaaaaaaaaa
      https://youtu.be/bbbbbbbbbbb
    TEXT
    expect(result.map(&:external_id)).to eq %w[aaaaaaaaaaa bbbbbbbbbbb]
  end

  it "同一動画の重複URLは1件に排除すること" do
    result = detect("https://youtu.be/dQw4w9WgXcQ https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expect(result.size).to eq 1
  end

  it "最大件数(3件)を超えるURLは打ち切ること" do
    result = detect(
      (1..5).map { |i| "https://youtu.be/#{format('vid%08d', i)}" }.join(" ")
    )
    expect(result.size).to eq 3
  end

  it "playlist URLは対象外とすること" do
    result = detect("https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
    expect(result).to eq []
  end

  it "YouTube以外のドメインは無視すること" do
    result = detect("https://example.com/watch?v=dQw4w9WgXcQ")
    expect(result).to eq []
  end

  it "HTTPS以外のプロトコルは無視すること" do
    result = detect("http://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expect(result).to eq []
  end

  it "不正なURLでも例外を発生させないこと" do
    expect { detect("https://[invalid") }.not_to raise_error
    expect(detect("https://[invalid")).to eq []
  end

  it "URLを含まない本文は空配列を返すこと" do
    expect(detect("こんにちは")).to eq []
  end

  it "空文字・nilは空配列を返すこと" do
    expect(detect("")).to eq []
    expect(detect(nil)).to eq []
  end

  describe "イベントURLの検出" do
    let(:community) { create(:community) }
    let(:customer) { create(:customer) }
    let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }

    it "許可された内部ホストの正しいイベントURLを検出すること" do
      result = detect("見て https://www.example.com/public/events/#{event.id}")

      expect(result.size).to eq 1
      expect(result.first.provider).to eq :event
      expect(result.first.external_id).to eq event.id.to_s
    end

    it "クエリ文字列・fragmentが付与されていても同じEvent IDに解決されること" do
      plain = detect("https://www.example.com/public/events/#{event.id}")
      with_query = detect("https://www.example.com/public/events/#{event.id}?utm_source=x&ref=y#section")

      expect(with_query.first.external_id).to eq plain.first.external_id
      expect(with_query.first.url).to eq plain.first.url
    end

    it "他ドメインの同一パスは拒否すること" do
      result = detect("https://evil-example.com/public/events/#{event.id}")
      expect(result).to eq []
    end

    it "管理画面URL(/admin/events/:id)は拒否すること" do
      result = detect("https://www.example.com/admin/events/#{event.id}")
      expect(result).to eq []
    end

    it "編集URL(/public/events/:id/edit)は拒否すること" do
      result = detect("https://www.example.com/public/events/#{event.id}/edit")
      expect(result).to eq []
    end

    it "数値以外のIDは拒否すること" do
      result = detect("https://www.example.com/public/events/abc")
      expect(result).to eq []
    end

    it "余分なパスが続くものは拒否すること" do
      result = detect("https://www.example.com/public/events/#{event.id}/foo")
      expect(result).to eq []
    end

    it "存在しないEventは検出しないこと" do
      result = detect("https://www.example.com/public/events/#{event.id + 1_000_000}")
      expect(result).to eq []
    end

    it "HTTPS以外のプロトコルは拒否すること" do
      result = detect("http://www.example.com/public/events/#{event.id}")
      expect(result).to eq []
    end
  end

  # config.x.chat_link_preview.internal_hostsが未設定・nilの場合でも、投稿全体が
  # 500にならないことを保証する(本番URLをローカルで貼った際にNoMethodErrorになった
  # 実障害の再発防止)。
  describe "internal_hosts設定の安全性" do
    let(:community) { create(:community) }
    let(:customer) { create(:customer) }
    let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }

    around do |example|
      original = Rails.application.config.x.chat_link_preview.internal_hosts
      example.run
      Rails.application.config.x.chat_link_preview.internal_hosts = original
    end

    it "internal_hostsがnilでも例外を発生させず、イベントURLを検出しないこと" do
      Rails.application.config.x.chat_link_preview.internal_hosts = nil

      expect { detect("https://www.example.com/public/events/#{event.id}") }.not_to raise_error
      expect(detect("https://www.example.com/public/events/#{event.id}")).to eq []
    end

    it "internal_hostsが空配列でも例外を発生させないこと" do
      Rails.application.config.x.chat_link_preview.internal_hosts = []

      expect { detect("https://www.example.com/public/events/#{event.id}") }.not_to raise_error
    end

    it "internal_hostsがnilでもYouTube検出には影響しないこと" do
      Rails.application.config.x.chat_link_preview.internal_hosts = nil

      result = detect("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      expect(result.first.provider).to eq :youtube
      expect(result.first.external_id).to eq "dQw4w9WgXcQ"
    end

    it "開発環境相当の設定(本番ホスト+localhost)でbe-my-style.comを検出できること" do
      Rails.application.config.x.chat_link_preview.internal_hosts = %w[be-my-style.com www.be-my-style.com localhost]

      result = detect("https://be-my-style.com/public/events/#{event.id}")
      expect(result.first.provider).to eq :event
      expect(result.first.external_id).to eq event.id.to_s
    end

    it "開発環境相当の設定でwww.be-my-style.comを検出できること" do
      Rails.application.config.x.chat_link_preview.internal_hosts = %w[be-my-style.com www.be-my-style.com localhost]

      result = detect("https://www.be-my-style.com/public/events/#{event.id}")
      expect(result.first.provider).to eq :event
      expect(result.first.external_id).to eq event.id.to_s
    end

    it "test環境相当の設定でwww.example.comを検出できること" do
      Rails.application.config.x.chat_link_preview.internal_hosts = %w[www.example.com]

      result = detect("https://www.example.com/public/events/#{event.id}")
      expect(result.first.provider).to eq :event
    end

    it "許可リストに無いホストは拒否されること" do
      Rails.application.config.x.chat_link_preview.internal_hosts = %w[be-my-style.com www.be-my-style.com]

      result = detect("https://evil.example/public/events/#{event.id}")
      expect(result).to eq []
    end
  end
end
