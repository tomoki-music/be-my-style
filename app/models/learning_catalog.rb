module LearningCatalog
  PARTS = {
    "vocal" => "Vocal",
    "guitar" => "Guitar",
    "bass" => "Bass",
    "drums" => "Drums",
    "keyboard" => "Keyboard",
    "band" => "Band"
  }.freeze

  PERIODS = [
    "1-2ヶ月",
    "1-3ヶ月",
    "3-4ヶ月",
    "3-6ヶ月",
    "5-6ヶ月",
    "6-9ヶ月",
    "7-9ヶ月",
    "9-12ヶ月",
    "10-12ヶ月",
    "常時"
  ].freeze

  LEVELS = [
    "基礎",
    "安定",
    "応用",
    "実践"
  ].freeze

  STUDENT_STATUSES = {
    "active" => "在籍中",
    "on_break" => "休会",
    "graduated" => "卒業"
  }.freeze

  TRAINING_STATUSES = {
    "not_started" => "未着手",
    "in_progress" => "進行中",
    "achieved" => "達成"
  }.freeze

  ACHIEVEMENT_MARKS = {
    "star" => "⭐",
    "triangle" => "△",
    "cross" => "×"
  }.freeze

  PART_THEMES = {
    "vocal" => { accent: "#d96876", soft: "#fff1f3", text: "#8f3a46" },
    "guitar" => { accent: "#e38d46", soft: "#fff5eb", text: "#8a4d1d" },
    "bass" => { accent: "#5d9b68", soft: "#eef8ef", text: "#356640" },
    "drums" => { accent: "#5a8ed6", soft: "#eef5ff", text: "#31548a" },
    "keyboard" => { accent: "#9271d8", soft: "#f4f0ff", text: "#5a4291" },
    "band" => { accent: "#7f8796", soft: "#f4f5f7", text: "#4d5563" }
  }.freeze

  module_function

  def part_options
    PARTS.map { |value, label| [label, value] }
  end

  def period_options
    PERIODS.map { |value| [value, value] }
  end

  def level_options
    LEVELS.map { |value| [value, value] }
  end

  def student_status_options
    STUDENT_STATUSES.map { |value, label| [label, value] }
  end

  def training_status_options
    TRAINING_STATUSES.map { |value, label| [label, value] }
  end

  def achievement_mark_options
    ACHIEVEMENT_MARKS.map { |value, label| [label, value] }
  end

  def label_for_part(part)
    PARTS[part.to_s] || part.to_s
  end

  def label_for_student_status(status)
    STUDENT_STATUSES[status.to_s] || status.to_s
  end

  def label_for_training_status(status)
    TRAINING_STATUSES[status.to_s] || status.to_s
  end

  def label_for_mark(mark)
    ACHIEVEMENT_MARKS[mark.to_s] || mark.to_s
  end
end
