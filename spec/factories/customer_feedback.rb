FactoryBot.define do
  factory :customer_feedback do
    association :customer
    category { :feature_request }
    subject { "検索の絞り込みを増やしてほしい" }
    body { "イベント検索でジャンル別に絞り込めると助かります。" }
    status { :unread }
  end
end
