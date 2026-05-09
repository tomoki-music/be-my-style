module LearningHelper
  def learning_part_options
    LearningCatalog.part_options
  end

  def learning_period_options
    LearningCatalog.period_options
  end

  def learning_level_options
    LearningCatalog.level_options
  end

  def learning_student_status_options
    LearningCatalog.student_status_options
  end

  def learning_school_group_options(school_groups)
    Array(school_groups).map { |group| [group.name, group.id] }
  end

  def learning_training_status_options
    LearningCatalog.training_status_options
  end

  def learning_achievement_mark_options
    LearningCatalog.achievement_mark_options
  end

  def learning_part_label(part)
    LearningCatalog.label_for_part(part)
  end

  def learning_student_status_label(status)
    LearningCatalog.label_for_student_status(status)
  end

  def learning_training_status_label(status)
    LearningCatalog.label_for_training_status(status)
  end

  def learning_mark_label(mark)
    LearningCatalog.label_for_mark(mark)
  end

  def learning_part_theme(part)
    LearningCatalog::PART_THEMES[part.to_s] || LearningCatalog::PART_THEMES["band"]
  end

  def learning_progress_style(part)
    theme = learning_part_theme(part)
    "--learning-accent: #{theme[:accent]}; --learning-soft: #{theme[:soft]}; --learning-text: #{theme[:text]};"
  end

  def learning_progress_bar_width(rate)
    [[rate.to_i, 0].max, 100].min
  end

  def learning_nav_active?(path)
    current_path = request.path
    current_path == path || current_path.start_with?("#{path}/")
  end
end
