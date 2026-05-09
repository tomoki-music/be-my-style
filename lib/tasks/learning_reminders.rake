# frozen_string_literal: true

namespace :learning do
  desc "Learning LINEリマインドを送信する。DRY_RUN=1で候補確認のみ、CUSTOMER_ID=123で対象限定"
  task send_reminders: :environment do
    dry_run = ENV["DRY_RUN"].present?
    customer_id = ENV["CUSTOMER_ID"].presence

    customers = if customer_id
                  Customer.where(id: customer_id)
                else
                  Customer.all
                end.select { |customer| customer.learning_user? || customer.admin? }

    totals = Hash.new(0)

    puts "[learning:send_reminders] #{dry_run ? 'DRY-RUN ' : ''}start"
    puts "  customers=#{customers.size}"
    puts "  line_token_configured=#{ENV['LINE_CHANNEL_ACCESS_TOKEN'].to_s.length.positive?}"

    customers.each do |customer|
      dispatcher = Learning::NotificationDispatcher.new(customer, channels: [:line])
      logs = dry_run ? dispatcher.preview : dispatcher.dispatch

      customer_counts = if dry_run
                          { previewed: logs.size }
                        else
                          logs.each_with_object(Hash.new(0)) { |log, counts| counts[log.status.to_sym] += 1 }
                        end

      customer_counts.each { |key, value| totals[key] += value }
      puts "  customer_id=#{customer.id} reminders=#{logs.size} #{customer_counts.map { |key, value| "#{key}=#{value}" }.join(' ')}"
    end

    puts "  total=#{totals.values.sum}"
    puts "  sent=#{totals[:sent]}"
    puts "  skipped=#{totals[:skipped]}"
    puts "  failed=#{totals[:failed]}"
    puts "  previewed=#{totals[:previewed]}"
    puts "[learning:send_reminders] done"
  end
end
