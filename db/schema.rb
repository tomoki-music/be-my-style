# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_05_11_020000) do

  create_table "active_admin_comments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "title"
    t.text "introduction"
    t.text "keep"
    t.text "problem"
    t.text "try"
    t.string "youtube_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "url"
    t.string "url_comment"
    t.index ["customer_id"], name: "index_activities_on_customer_id"
  end

  create_table "activity_reactions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "activity_id", null: false
    t.string "reaction_type", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["activity_id"], name: "index_activity_reactions_on_activity_id"
    t.index ["customer_id", "activity_id", "reaction_type"], name: "index_activity_reactions_unique", unique: true
    t.index ["customer_id"], name: "index_activity_reactions_on_customer_id"
  end

  create_table "admin_notifications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.bigint "customer_id", null: false
    t.string "action", limit: 50, default: "", null: false
    t.string "plan", limit: 30, null: false
    t.string "stripe_subscription_id", limit: 100
    t.text "message"
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["admin_id", "customer_id", "action", "plan", "stripe_subscription_id"], name: "index_admin_notifications_on_subscription_event"
    t.index ["admin_id"], name: "index_admin_notifications_on_admin_id"
    t.index ["customer_id"], name: "index_admin_notifications_on_customer_id"
  end

  create_table "admin_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "admins", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "chat_messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "chat_room_id", null: false
    t.bigint "customer_id", null: false
    t.text "content"
    t.bigint "community_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "stamp_type"
    t.index ["chat_room_id"], name: "index_chat_messages_on_chat_room_id"
    t.index ["community_id"], name: "index_chat_messages_on_community_id"
    t.index ["customer_id"], name: "index_chat_messages_on_customer_id"
  end

  create_table "chat_room_customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "chat_room_id"
    t.bigint "customer_id"
    t.bigint "community_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["chat_room_id"], name: "index_chat_room_customers_on_chat_room_id"
    t.index ["community_id"], name: "index_chat_room_customers_on_community_id"
    t.index ["customer_id"], name: "index_chat_room_customers_on_customer_id"
  end

  create_table "chat_rooms", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "comments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "comment"
    t.bigint "customer_id", null: false
    t.bigint "activity_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "stamp_type"
    t.index ["activity_id"], name: "index_comments_on_activity_id"
    t.index ["customer_id"], name: "index_comments_on_customer_id"
  end

  create_table "communities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.text "introduction"
    t.integer "owner_id"
    t.integer "activity_stance"
    t.text "favorite_artist1"
    t.text "favorite_artist2"
    t.text "favorite_artist3"
    t.text "favorite_artist4"
    t.text "favorite_artist5"
    t.text "url"
    t.integer "prefecture_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "domain_id", null: false
    t.index ["domain_id"], name: "index_communities_on_domain_id"
  end

  create_table "community_customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id"
    t.bigint "community_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["community_id"], name: "index_community_customers_on_community_id"
    t.index ["customer_id"], name: "index_community_customers_on_customer_id"
  end

  create_table "community_domains", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.bigint "domain_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["community_id"], name: "index_community_domains_on_community_id"
    t.index ["domain_id"], name: "index_community_domains_on_domain_id"
  end

  create_table "community_genres", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.bigint "genre_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["community_id"], name: "index_community_genres_on_community_id"
    t.index ["genre_id"], name: "index_community_genres_on_genre_id"
  end

  create_table "community_owners", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["community_id"], name: "index_community_owners_on_community_id"
    t.index ["customer_id"], name: "index_community_owners_on_customer_id"
  end

  create_table "community_posts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "community_id", null: false
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["community_id"], name: "index_community_posts_on_community_id"
    t.index ["customer_id"], name: "index_community_posts_on_customer_id"
  end

  create_table "customer_domains", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "domain_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "domain_id"], name: "index_customer_domains_on_customer_id_and_domain_id", unique: true
    t.index ["customer_id"], name: "index_customer_domains_on_customer_id"
    t.index ["domain_id"], name: "index_customer_domains_on_domain_id"
  end

  create_table "customer_genres", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "genre_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_customer_genres_on_customer_id"
    t.index ["genre_id"], name: "index_customer_genres_on_genre_id"
  end

  create_table "customer_parts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "part_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_customer_parts_on_customer_id"
    t.index ["part_id"], name: "index_customer_parts_on_part_id"
  end

  create_table "customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.integer "postal_code"
    t.string "address"
    t.string "tell"
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "introduction"
    t.integer "sex"
    t.date "birthday"
    t.integer "activity_stance"
    t.text "favorite_artist1"
    t.text "favorite_artist2"
    t.text "favorite_artist3"
    t.text "favorite_artist4"
    t.text "favorite_artist5"
    t.text "url"
    t.integer "prefecture_id"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.boolean "confirm_mail", default: true
    t.integer "is_owner"
    t.string "job"
    t.text "skills"
    t.text "achievements"
    t.boolean "onboarding_done"
    t.string "singing_profile_comment", limit: 120
    t.index ["email"], name: "index_customers_on_email", unique: true
    t.index ["reset_password_token"], name: "index_customers_on_reset_password_token", unique: true
  end

  create_table "domains", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_domains_on_name", unique: true
  end

  create_table "events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "community_id", null: false
    t.string "event_name", null: false
    t.datetime "event_start_time", null: false
    t.datetime "event_end_time", null: false
    t.integer "entrance_fee", null: false
    t.text "introduction"
    t.string "place", null: false
    t.string "address", null: false
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "url"
    t.string "url_comment"
    t.datetime "event_entry_deadline", null: false
    t.datetime "request_deadline"
    t.index ["community_id"], name: "index_events_on_community_id"
    t.index ["customer_id"], name: "index_events_on_customer_id"
  end

  create_table "favorites", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "activity_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["activity_id"], name: "index_favorites_on_activity_id"
    t.index ["customer_id"], name: "index_favorites_on_customer_id"
  end

  create_table "genres", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "join_part_customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "join_part_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "session_credit_applied", default: false, null: false
    t.integer "session_credit_amount", default: 0, null: false
    t.string "plan_snapshot"
    t.index ["customer_id"], name: "index_join_part_customers_on_customer_id"
    t.index ["join_part_id"], name: "index_join_part_customers_on_join_part_id"
  end

  create_table "join_parts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "song_id", null: false
    t.string "join_part_name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["song_id"], name: "index_join_parts_on_song_id"
  end

  create_table "learning_assignments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_student_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "pending", null: false
    t.date "due_on"
    t.datetime "completed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "assignment_group_key"
    t.index ["customer_id", "assignment_group_key"], name: "index_learning_assignments_on_customer_group_key"
    t.index ["customer_id", "learning_student_id", "status"], name: "index_learning_assignments_on_customer_student_status"
    t.index ["customer_id"], name: "index_learning_assignments_on_customer_id"
    t.index ["due_on"], name: "index_learning_assignments_on_due_on"
    t.index ["learning_student_id", "status", "created_at"], name: "index_learning_assignments_on_student_status_created_at"
    t.index ["learning_student_id"], name: "index_learning_assignments_on_learning_student_id"
    t.index ["status"], name: "index_learning_assignments_on_status"
  end

  create_table "learning_band_memberships", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "learning_band_id", null: false
    t.bigint "learning_student_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["learning_band_id", "learning_student_id"], name: "index_learning_band_memberships_on_band_and_student", unique: true
    t.index ["learning_band_id"], name: "index_learning_band_memberships_on_learning_band_id"
    t.index ["learning_student_id"], name: "index_learning_band_memberships_on_learning_student_id"
  end

  create_table "learning_band_trainings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_band_id", null: false
    t.bigint "learning_training_master_id"
    t.string "part", default: "band", null: false
    t.string "period", null: false
    t.string "level", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.text "achievement_criteria"
    t.string "frequency"
    t.string "status", default: "not_started", null: false
    t.string "achievement_mark", default: "cross", null: false
    t.text "teacher_comment"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "related_parts"
    t.index ["customer_id"], name: "index_learning_band_trainings_on_customer_id"
    t.index ["learning_band_id", "position"], name: "index_learning_band_trainings_on_band_and_position"
    t.index ["learning_band_id"], name: "index_learning_band_trainings_on_learning_band_id"
    t.index ["learning_training_master_id"], name: "index_learning_band_trainings_on_learning_training_master_id"
  end

  create_table "learning_bands", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.text "memo"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "name"], name: "index_learning_bands_on_customer_id_and_name", unique: true
    t.index ["customer_id"], name: "index_learning_bands_on_customer_id"
  end

  create_table "learning_effort_points", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_student_id", null: false
    t.string "point_type", null: false
    t.integer "points", default: 0, null: false
    t.string "description", limit: 100
    t.date "earned_on", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_learning_effort_points_on_customer_id"
    t.index ["learning_student_id", "earned_on"], name: "index_learning_effort_points_on_student_and_date"
    t.index ["learning_student_id", "point_type", "earned_on"], name: "index_learning_effort_points_on_student_type_date"
    t.index ["learning_student_id"], name: "index_learning_effort_points_on_learning_student_id"
  end

  create_table "learning_line_connections", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_student_id"
    t.string "line_user_id"
    t.string "display_name"
    t.string "status", default: "pending", null: false
    t.datetime "connected_at"
    t.datetime "last_notified_at"
    t.json "metadata"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "connect_token"
    t.datetime "expires_at"
    t.index ["connect_token"], name: "index_learning_line_connections_on_connect_token", unique: true
    t.index ["customer_id"], name: "index_learning_line_connections_on_customer_id"
    t.index ["expires_at"], name: "index_learning_line_connections_on_expires_at"
    t.index ["learning_student_id"], name: "index_learning_line_connections_on_learning_student_id"
    t.index ["line_user_id"], name: "index_learning_line_connections_on_line_user_id"
    t.index ["status"], name: "index_learning_line_connections_on_status"
  end

  create_table "learning_line_message_templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "title", null: false
    t.string "category", null: false
    t.text "body", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "active"], name: "idx_learning_line_templates_on_customer_active"
    t.index ["customer_id", "category"], name: "idx_learning_line_templates_on_customer_category"
    t.index ["customer_id"], name: "index_learning_line_message_templates_on_customer_id"
  end

  create_table "learning_monthly_reports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.date "report_month", null: false
    t.integer "total_students", default: 0, null: false
    t.integer "total_progress_logs", default: 0, null: false
    t.integer "total_achieved_trainings", default: 0, null: false
    t.decimal "avg_achievement_rate", precision: 5, scale: 2, default: "0.0"
    t.string "status", default: "generated", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "report_month"], name: "index_learning_monthly_reports_on_customer_and_month", unique: true
    t.index ["customer_id"], name: "index_learning_monthly_reports_on_customer_id"
  end

  create_table "learning_notification_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_student_id"
    t.string "notification_type", null: false
    t.string "level"
    t.string "delivery_channel", default: "manual", null: false
    t.string "status", default: "previewed", null: false
    t.string "title"
    t.text "message", null: false
    t.string "recommended_action"
    t.datetime "generated_at", null: false
    t.datetime "sent_at"
    t.text "error_message"
    t.json "metadata"
    t.boolean "reaction_received", default: false, null: false
    t.datetime "reacted_at"
    t.string "reaction_message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "learning_student_id", "notification_type", "generated_at"], name: "index_learning_notification_logs_on_daily_dedupe_lookup"
    t.index ["customer_id"], name: "index_learning_notification_logs_on_customer_id"
    t.index ["generated_at"], name: "index_learning_notification_logs_on_generated_at"
    t.index ["learning_student_id"], name: "index_learning_notification_logs_on_learning_student_id"
    t.index ["learning_student_id", "reaction_received", "sent_at"], name: "index_learning_notification_logs_on_student_reaction"
    t.index ["notification_type"], name: "index_learning_notification_logs_on_notification_type"
    t.index ["reacted_at"], name: "index_learning_notification_logs_on_reacted_at"
    t.index ["status"], name: "index_learning_notification_logs_on_status"
  end

  create_table "learning_notification_settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.boolean "reminder_enabled", default: true, null: false
    t.boolean "teacher_summary_enabled", default: true, null: false
    t.boolean "student_reactivation_enabled", default: true, null: false
    t.string "delivery_channel", default: "manual", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_learning_notification_settings_on_customer_id", unique: true
  end

  create_table "learning_portal_accesses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "learning_student_id", null: false
    t.date "accessed_on", null: false
    t.integer "streak_count", default: 1, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["learning_student_id", "accessed_on"], name: "index_learning_portal_accesses_unique_daily", unique: true
    t.index ["learning_student_id"], name: "index_learning_portal_accesses_on_learning_student_id"
  end

  create_table "learning_progress_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_student_id", null: false
    t.bigint "learning_student_training_id"
    t.string "part", null: false
    t.string "training_title", null: false
    t.date "practiced_on", null: false
    t.string "achievement_mark", default: "triangle", null: false
    t.text "comment"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "practiced_on"], name: "index_learning_progress_logs_on_customer_id_and_practiced_on"
    t.index ["customer_id"], name: "index_learning_progress_logs_on_customer_id"
    t.index ["learning_student_id", "practiced_on"], name: "index_learning_progress_logs_on_student_and_date"
    t.index ["learning_student_id"], name: "index_learning_progress_logs_on_learning_student_id"
    t.index ["learning_student_training_id"], name: "index_learning_progress_logs_on_learning_student_training_id"
  end

  create_table "learning_school_applications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "school_name", limit: 100, null: false
    t.string "advisor_name", limit: 50, null: false
    t.string "email", null: false
    t.integer "student_count"
    t.text "message"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_learning_school_applications_on_email"
    t.index ["status"], name: "index_learning_school_applications_on_status"
  end

  create_table "learning_school_groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.text "memo"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "school_code", limit: 20
    t.string "advisor_name", limit: 100
    t.index ["customer_id", "name"], name: "index_learning_school_groups_on_customer_id_and_name", unique: true
    t.index ["customer_id", "school_code"], name: "index_learning_school_groups_on_customer_and_code", unique: true
    t.index ["customer_id"], name: "index_learning_school_groups_on_customer_id"
  end

  create_table "learning_student_parts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "learning_student_id", null: false
    t.string "part", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["learning_student_id", "part"], name: "index_learning_student_parts_on_student_and_part", unique: true
    t.index ["learning_student_id"], name: "index_learning_student_parts_on_learning_student_id"
  end

  create_table "learning_student_trainings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "learning_student_id", null: false
    t.bigint "learning_training_master_id"
    t.string "part", null: false
    t.string "period", null: false
    t.string "level", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.text "achievement_criteria"
    t.string "frequency"
    t.string "status", default: "not_started", null: false
    t.string "achievement_mark", default: "cross", null: false
    t.string "weekly_goal"
    t.text "teacher_comment"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "status"], name: "index_learning_student_trainings_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_learning_student_trainings_on_customer_id"
    t.index ["learning_student_id", "position"], name: "index_learning_student_trainings_on_student_and_position"
    t.index ["learning_student_id"], name: "index_learning_student_trainings_on_learning_student_id"
    t.index ["learning_training_master_id"], name: "index_learning_student_trainings_on_learning_training_master_id"
  end

  create_table "learning_students", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.string "main_part", null: false
    t.string "grade"
    t.text "memo"
    t.string "status", default: "active", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "learning_school_group_id"
    t.string "email"
    t.string "public_access_token"
    t.string "nickname", limit: 30
    t.boolean "tutorial_completed", default: false, null: false
    t.integer "total_effort_points", default: 0, null: false
    t.datetime "last_learning_action_at"
    t.index ["customer_id", "email"], name: "index_learning_students_on_customer_id_and_email"
    t.index ["customer_id", "learning_school_group_id"], name: "index_learning_students_on_customer_and_school_group"
    t.index ["customer_id", "name"], name: "index_learning_students_on_customer_id_and_name"
    t.index ["customer_id", "status"], name: "index_learning_students_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_learning_students_on_customer_id"
    t.index ["last_learning_action_at"], name: "index_learning_students_on_last_learning_action_at"
    t.index ["learning_school_group_id"], name: "index_learning_students_on_learning_school_group_id"
    t.index ["public_access_token"], name: "index_learning_students_on_public_access_token", unique: true
  end

  create_table "learning_training_masters", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "part", null: false
    t.string "period", null: false
    t.string "level", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.text "achievement_criteria"
    t.string "frequency"
    t.boolean "is_band_training", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "level"], name: "index_learning_training_masters_on_customer_id_and_level"
    t.index ["customer_id", "part"], name: "index_learning_training_masters_on_customer_id_and_part"
    t.index ["customer_id", "period"], name: "index_learning_training_masters_on_customer_id_and_period"
    t.index ["customer_id"], name: "index_learning_training_masters_on_customer_id"
  end

  create_table "likes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "post_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_likes_on_customer_id"
    t.index ["post_id"], name: "index_likes_on_post_id"
  end

  create_table "member_profiles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "entry_source"
    t.text "join_reason"
    t.text "want_to_do"
    t.integer "music_experience_level", default: 0, null: false
    t.integer "engagement_style", default: 0, null: false
    t.integer "suggested_member_type", default: 0, null: false
    t.integer "contact_preference", default: 0, null: false
    t.text "admin_memo"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_member_profiles_on_customer_id"
  end

  create_table "messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "post_id", null: false
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "stamp_type"
    t.index ["customer_id"], name: "index_messages_on_customer_id"
    t.index ["post_id"], name: "index_messages_on_post_id"
  end

  create_table "notifications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "visitor_id", null: false
    t.integer "visited_id", null: false
    t.integer "event_id"
    t.integer "comment_id"
    t.string "action", default: "", null: false
    t.boolean "checked", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "community_id"
    t.integer "activity_id"
    t.integer "post_id"
    t.integer "project_id"
    t.index ["comment_id"], name: "index_notifications_on_comment_id"
    t.index ["event_id"], name: "index_notifications_on_event_id"
    t.index ["post_id"], name: "index_notifications_on_post_id"
    t.index ["project_id"], name: "index_notifications_on_project_id"
    t.index ["visited_id"], name: "index_notifications_on_visited_id"
    t.index ["visitor_id"], name: "index_notifications_on_visitor_id"
  end

  create_table "parts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "permits", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["community_id"], name: "index_permits_on_community_id"
    t.index ["customer_id"], name: "index_permits_on_customer_id"
  end

  create_table "posts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "title"
    t.text "body"
    t.integer "category"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "tags"
    t.integer "project_id"
    t.index ["customer_id"], name: "index_posts_on_customer_id"
  end

  create_table "project_chats", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "customer_id", null: false
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_project_chats_on_customer_id"
    t.index ["project_id"], name: "index_project_chats_on_project_id"
  end

  create_table "project_members", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_project_members_on_customer_id"
    t.index ["project_id"], name: "index_project_members_on_project_id"
  end

  create_table "projects", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.bigint "customer_id", null: false
    t.string "title"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "status", default: 0
    t.datetime "deadline"
    t.string "goal"
    t.index ["community_id"], name: "index_projects_on_community_id"
    t.index ["customer_id"], name: "index_projects_on_customer_id"
  end

  create_table "relationships", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "follower_id"
    t.integer "followed_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "requests", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "request"
    t.bigint "customer_id", null: false
    t.bigint "event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "stamp_type"
    t.index ["customer_id"], name: "index_requests_on_customer_id"
    t.index ["event_id"], name: "index_requests_on_event_id"
  end

  create_table "singing_badges", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "singing_ranking_season_id", null: false
    t.string "badge_type", null: false
    t.datetime "awarded_at", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "singing_ranking_season_id", "badge_type"], name: "index_singing_badges_unique", unique: true
    t.index ["customer_id"], name: "index_singing_badges_on_customer_id"
    t.index ["singing_ranking_season_id"], name: "index_singing_badges_on_season_id"
  end

  create_table "singing_diagnoses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "song_title"
    t.text "memo"
    t.integer "status", default: 0, null: false
    t.integer "overall_score"
    t.integer "pitch_score"
    t.integer "rhythm_score"
    t.integer "expression_score"
    t.text "result_payload"
    t.datetime "diagnosed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "failure_reason"
    t.text "ai_comment"
    t.integer "ai_comment_status", default: 0, null: false
    t.text "ai_comment_failure_reason"
    t.datetime "ai_commented_at"
    t.integer "performance_type", default: 0, null: false
    t.boolean "ranking_opt_in", default: false, null: false
    t.index ["ai_comment_status"], name: "index_singing_diagnoses_on_ai_comment_status"
    t.index ["customer_id"], name: "index_singing_diagnoses_on_customer_id"
    t.index ["diagnosed_at"], name: "index_singing_diagnoses_on_diagnosed_at"
    t.index ["performance_type"], name: "index_singing_diagnoses_on_performance_type"
    t.index ["ranking_opt_in"], name: "index_singing_diagnoses_on_ranking_opt_in"
    t.index ["status"], name: "index_singing_diagnoses_on_status"
  end

  create_table "singing_profile_reactions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "target_customer_id", null: false
    t.string "reaction_type", limit: 40, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id", "target_customer_id", "reaction_type"], name: "index_singing_profile_reactions_unique", unique: true
    t.index ["customer_id"], name: "index_singing_profile_reactions_on_customer_id"
    t.index ["target_customer_id", "reaction_type"], name: "index_singing_profile_reactions_on_target_and_type"
    t.index ["target_customer_id"], name: "index_singing_profile_reactions_on_target_customer_id"
  end

  create_table "singing_ranking_seasons", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.string "status", default: "draft", null: false
    t.string "season_type", default: "monthly", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["ends_on"], name: "index_singing_ranking_seasons_on_ends_on"
    t.index ["starts_on"], name: "index_singing_ranking_seasons_on_starts_on"
    t.index ["status"], name: "index_singing_ranking_seasons_on_status"
  end

  create_table "singing_season_ranking_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "singing_ranking_season_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "singing_diagnosis_id"
    t.integer "rank", null: false
    t.integer "score", null: false
    t.string "category", default: "overall", null: false
    t.string "title"
    t.string "badge_key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["category"], name: "index_singing_season_ranking_entries_on_category"
    t.index ["customer_id"], name: "index_singing_season_ranking_entries_on_customer_id"
    t.index ["rank"], name: "index_singing_season_ranking_entries_on_rank"
    t.index ["singing_diagnosis_id"], name: "index_singing_season_ranking_entries_on_singing_diagnosis_id"
    t.index ["singing_ranking_season_id", "customer_id", "category"], name: "index_season_ranking_entries_unique", unique: true
    t.index ["singing_ranking_season_id"], name: "index_season_entries_on_season_id"
  end

  create_table "song_customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "song_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_song_customers_on_customer_id"
    t.index ["song_id"], name: "index_song_customers_on_song_id"
  end

  create_table "songs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "song_name", null: false
    t.string "youtube_url"
    t.text "introduction"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "position"
    t.string "performance_time"
    t.string "performance_start_time"
    t.index ["event_id"], name: "index_songs_on_event_id"
  end

  create_table "subscriptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "status"
    t.string "plan"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
  end

  create_table "taggings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "tag_id"
    t.string "taggable_type"
    t.bigint "taggable_id"
    t.string "tagger_type"
    t.bigint "tagger_id"
    t.string "context", limit: 128
    t.datetime "created_at"
    t.string "tenant", limit: 128
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tagger_type", "tagger_id"], name: "index_taggings_on_tagger_type_and_tagger_id"
    t.index ["tenant"], name: "index_taggings_on_tenant"
  end

  create_table "tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", collation: "utf8mb3_bin"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "customers"
  add_foreign_key "activity_reactions", "activities"
  add_foreign_key "activity_reactions", "customers"
  add_foreign_key "admin_notifications", "admins"
  add_foreign_key "admin_notifications", "customers"
  add_foreign_key "chat_messages", "chat_rooms"
  add_foreign_key "chat_messages", "communities"
  add_foreign_key "chat_messages", "customers"
  add_foreign_key "chat_room_customers", "chat_rooms"
  add_foreign_key "chat_room_customers", "communities"
  add_foreign_key "chat_room_customers", "customers"
  add_foreign_key "comments", "activities"
  add_foreign_key "comments", "customers"
  add_foreign_key "communities", "domains"
  add_foreign_key "community_customers", "communities"
  add_foreign_key "community_customers", "customers"
  add_foreign_key "community_domains", "communities"
  add_foreign_key "community_domains", "domains"
  add_foreign_key "community_genres", "communities"
  add_foreign_key "community_genres", "genres"
  add_foreign_key "community_owners", "communities"
  add_foreign_key "community_owners", "customers"
  add_foreign_key "community_posts", "communities"
  add_foreign_key "community_posts", "customers"
  add_foreign_key "customer_domains", "customers"
  add_foreign_key "customer_domains", "domains"
  add_foreign_key "customer_genres", "customers"
  add_foreign_key "customer_genres", "genres"
  add_foreign_key "customer_parts", "customers"
  add_foreign_key "customer_parts", "parts"
  add_foreign_key "events", "communities"
  add_foreign_key "events", "customers"
  add_foreign_key "favorites", "activities"
  add_foreign_key "favorites", "customers"
  add_foreign_key "join_part_customers", "customers"
  add_foreign_key "join_part_customers", "join_parts"
  add_foreign_key "join_parts", "songs"
  add_foreign_key "learning_assignments", "customers"
  add_foreign_key "learning_assignments", "learning_students"
  add_foreign_key "learning_band_memberships", "learning_bands"
  add_foreign_key "learning_band_memberships", "learning_students"
  add_foreign_key "learning_band_trainings", "customers"
  add_foreign_key "learning_band_trainings", "learning_bands"
  add_foreign_key "learning_band_trainings", "learning_training_masters"
  add_foreign_key "learning_bands", "customers"
  add_foreign_key "learning_effort_points", "customers"
  add_foreign_key "learning_effort_points", "learning_students"
  add_foreign_key "learning_line_connections", "customers"
  add_foreign_key "learning_line_connections", "learning_students"
  add_foreign_key "learning_line_message_templates", "customers"
  add_foreign_key "learning_monthly_reports", "customers"
  add_foreign_key "learning_notification_logs", "customers"
  add_foreign_key "learning_notification_logs", "learning_students"
  add_foreign_key "learning_notification_settings", "customers"
  add_foreign_key "learning_portal_accesses", "learning_students"
  add_foreign_key "learning_progress_logs", "customers"
  add_foreign_key "learning_progress_logs", "learning_student_trainings"
  add_foreign_key "learning_progress_logs", "learning_students"
  add_foreign_key "learning_school_groups", "customers"
  add_foreign_key "learning_student_parts", "learning_students"
  add_foreign_key "learning_student_trainings", "customers"
  add_foreign_key "learning_student_trainings", "learning_students"
  add_foreign_key "learning_student_trainings", "learning_training_masters"
  add_foreign_key "learning_students", "customers"
  add_foreign_key "learning_students", "learning_school_groups"
  add_foreign_key "learning_training_masters", "customers"
  add_foreign_key "likes", "customers"
  add_foreign_key "likes", "posts"
  add_foreign_key "member_profiles", "customers"
  add_foreign_key "messages", "customers"
  add_foreign_key "messages", "posts"
  add_foreign_key "permits", "communities"
  add_foreign_key "permits", "customers"
  add_foreign_key "posts", "customers"
  add_foreign_key "project_chats", "customers"
  add_foreign_key "project_chats", "projects"
  add_foreign_key "project_members", "customers"
  add_foreign_key "project_members", "projects"
  add_foreign_key "projects", "communities"
  add_foreign_key "projects", "customers"
  add_foreign_key "requests", "customers"
  add_foreign_key "requests", "events"
  add_foreign_key "singing_badges", "customers"
  add_foreign_key "singing_badges", "singing_ranking_seasons"
  add_foreign_key "singing_diagnoses", "customers"
  add_foreign_key "singing_profile_reactions", "customers"
  add_foreign_key "singing_profile_reactions", "customers", column: "target_customer_id"
  add_foreign_key "singing_season_ranking_entries", "customers"
  add_foreign_key "singing_season_ranking_entries", "singing_diagnoses"
  add_foreign_key "singing_season_ranking_entries", "singing_ranking_seasons"
  add_foreign_key "song_customers", "customers"
  add_foreign_key "song_customers", "songs"
  add_foreign_key "songs", "events"
  add_foreign_key "subscriptions", "customers"
  add_foreign_key "taggings", "tags"
end
