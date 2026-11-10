# 画像の表示位置(横・縦 0〜100%)を元画像とは別に持つ。表示側は object-fit: cover の枠に
# object-position として渡すので、縦横比の違う枠でも同じ基準点で切り抜かれる。
# 列が NULL のときは未調整として扱い、style を出さない(=これまでどおり中央基準のまま)。
module ImagePositionable
  extend ActiveSupport::Concern

  AXES = %w[x y].freeze

  class_methods do
    def image_position_for(attachment_name)
      columns = AXES.map { |axis| "#{attachment_name}_position_#{axis}" }

      validates(*columns, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true)

      # 新しい画像に差し替えたのに位置が送られていなければ、前の画像の位置を持ち越さない。
      before_validation do
        next unless attachment_changes.key?(attachment_name.to_s)
        next if columns.any? { |column| has_attribute?(column) && will_save_change_to_attribute?(column) }

        columns.each { |column| self[column] = nil if has_attribute?(column) }
      end

      define_method("#{attachment_name}_object_position") do
        return nil unless columns.all? { |column| has_attribute?(column) }

        x, y = columns.map { |column| self[column] }
        return nil if x.nil? && y.nil?

        [x, y].map { |value| "#{ImagePositionable.format_percent(value)}%" }.join(" ")
      end
    end
  end

  def self.format_percent(value)
    number = (value.nil? ? 50 : value).to_d.clamp(0, 100).to_d
    number.round(2).to_s("F").sub(/\.?0+\z/, "")
  end
end
