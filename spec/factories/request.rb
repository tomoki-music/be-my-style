FactoryBot.define do
  factory :request do
    customer
    event
    request { "オリジナルソングを１曲お願いします！" }
  end
end