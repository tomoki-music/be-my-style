require "rails_helper"

RSpec.describe Learning::LineConnection, type: :model do
  describe "associations" do
    it "customer と任意の learning_student に紐づくこと" do
      connection = build(:learning_line_connection)

      expect(connection.customer).to be_present
      expect(connection.learning_student).to be_present
    end

    it "learning_student は未設定でも有効であること" do
      connection = build(:learning_line_connection, learning_student: nil)

      expect(connection).to be_valid
    end
  end

  describe "validations" do
    it "必須項目が揃っていれば有効であること" do
      expect(build(:learning_line_connection)).to be_valid
    end

    it "customer は必須であること" do
      expect(build(:learning_line_connection, customer: nil)).not_to be_valid
    end

    it "line_user_id は必須であること" do
      expect(build(:learning_line_connection, line_user_id: nil)).not_to be_valid
    end

    it "status は許可された値のみ有効であること" do
      expect(build(:learning_line_connection, status: "unknown")).not_to be_valid
    end
  end
end
