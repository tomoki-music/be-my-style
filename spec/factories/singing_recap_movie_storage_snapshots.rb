FactoryBot.define do
  factory :singing_recap_movie_storage_snapshot do
    sequence(:snapshot_date) { |n| n.days.ago.to_date }
    attached_movie_count     { 0 }
    total_bytes              { 0 }
    avg_bytes                { 0 }
    completed_bytes          { 0 }
    expired_attached_bytes   { 0 }
    recent_bytes             { 0 }
    estimated_monthly_cost_usd { 0.0 }
  end
end
