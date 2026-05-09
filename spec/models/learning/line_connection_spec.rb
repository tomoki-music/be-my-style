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

    it "未連携状態では line_user_id がなくても有効であること" do
      expect(build(:learning_line_connection, line_user_id: nil, status: "pending")).to be_valid
    end

    it "連携済み状態では line_user_id が必須であること" do
      expect(build(:learning_line_connection, line_user_id: nil, status: "connected")).not_to be_valid
    end

    it "status は許可された値のみ有効であること" do
      expect(build(:learning_line_connection, status: "unknown")).not_to be_valid
    end
  end

  describe "#issue_connect_token!" do
    it "24時間有効な接続トークンを発行すること" do
      connection = create(:learning_line_connection, line_user_id: nil, status: "pending")

      connection.issue_connect_token!

      expect(connection.connect_token).to be_present
      expect(connection.expires_at).to be > 23.hours.from_now
      expect(connection).to be_token_active
    end
  end

  describe "#complete_connection!" do
    it "連携済みにし、トークンを一度で無効化すること" do
      connection = create(:learning_line_connection, line_user_id: nil, status: "pending")
      connection.issue_connect_token!

      connection.complete_connection!(line_user_id: "dummy-line-user-1", display_name: "生徒")

      expect(connection).to be_connected
      expect(connection.line_user_id).to eq("dummy-line-user-1")
      expect(connection.connect_token).to be_nil
      expect(connection.expires_at).to be_nil
      expect(connection.connected_at).to be_present
    end
  end
end
