FactoryBot.define do
  factory :comment do
    customer
    activity
    comment { "MMM最高ですね！" }
  end
end