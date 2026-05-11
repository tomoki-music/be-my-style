# frozen_string_literal: true

namespace :learning do
  desc "Learning自動フォロー・自動リマインドを送信する。DRY_RUN=1で候補確認のみ、CUSTOMER_ID=123で対象限定"
  task auto_reminders: :environment do
    dry_run = ENV["DRY_RUN"].present?
    customer_id = ENV["CUSTOMER_ID"].presence

    customers = if customer_id
                  Customer.where(id: customer_id)
                else
                  Customer.all
                end.select { |customer| customer.learning_user? || customer.admin? }

    totals = Hash.new(0)

    puts "[learning:auto_reminders] #{dry_run ? 'DRY-RUN ' : ''}start"
    puts "  customers=#{customers.size}"
    puts "  line_token_configured=#{ENV['LINE_CHANNEL_ACCESS_TOKEN'].to_s.length.positive?}"

    customers.each do |customer|
      service = Learning::AutoReminderService.new(customer, dry_run: dry_run)
      results = service.call
      summary = service.summary

      results.each { |result| totals[result.status.to_sym] += 1 }

      puts "  customer_id=#{customer.id} candidates=#{results.size} inactive=#{summary.inactive_count} due_tomorrow=#{summary.due_tomorrow_count} overdue=#{summary.overdue_count}"
      results.each do |result|
        candidate = result.candidate
        assignment_label = candidate.assignment ? " assignment_id=#{candidate.assignment.id}" : ""
        puts "    student_id=#{candidate.student.id} student=#{candidate.student.display_name} type=#{candidate.notification_type} status=#{result.status} reason=#{candidate.reason}#{assignment_label}"
        puts "      message=#{candidate.message}"
      end
    end

    puts "  total=#{totals.values.sum}"
    puts "  sent=#{totals[:sent]}"
    puts "  skipped=#{totals[:skipped]}"
    puts "  failed=#{totals[:failed]}"
    puts "  previewed=#{totals[:previewed]}"
    puts "[learning:auto_reminders] done"
  end
end
