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

ActiveRecord::Schema.define(version: 2026_03_13_175703) do

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

  create_table "applications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "customer_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.string "status", default: "pending", null: false
    t.text "message"
    t.datetime "submitted_at"
    t.datetime "reviewed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_applications_on_customer_id"
    t.index ["status"], name: "index_applications_on_status"
    t.index ["target_type", "target_id"], name: "index_applications_on_target_type_and_target_id"
    t.index ["workspace_id"], name: "index_applications_on_workspace_id"
  end

  create_table "approvals", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "reviewer_id", null: false
    t.string "decision", null: false
    t.text "comment"
    t.datetime "decided_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["application_id"], name: "index_approvals_on_application_id"
    t.index ["decision"], name: "index_approvals_on_decision"
    t.index ["reviewer_id"], name: "index_approvals_on_reviewer_id"
  end

  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["workspace_id", "kind", "name"], name: "index_categories_on_workspace_id_and_kind_and_name", unique: true
    t.index ["workspace_id"], name: "index_categories_on_workspace_id"
  end

  create_table "category_assignments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["category_id", "target_type", "target_id"], name: "index_category_assignments_on_category_and_target", unique: true
    t.index ["category_id"], name: "index_category_assignments_on_category_id"
    t.index ["target_type", "target_id"], name: "index_category_assignments_on_target_type_and_target_id"
  end

  create_table "chat_messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "chat_room_id", null: false
    t.bigint "customer_id", null: false
    t.text "content"
    t.bigint "community_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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

  create_table "custom_field_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "entity_type", null: false
    t.string "field_key", null: false
    t.string "label", null: false
    t.string "field_type", null: false
    t.boolean "required", default: false, null: false
    t.json "options"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["workspace_id", "entity_type", "field_key"], name: "index_custom_field_definitions_on_workspace_and_entity_and_key", unique: true
    t.index ["workspace_id"], name: "index_custom_field_definitions_on_workspace_id"
  end

  create_table "custom_field_values", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "custom_field_definition_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.text "value_text"
    t.decimal "value_number", precision: 15, scale: 4
    t.boolean "value_boolean"
    t.date "value_date"
    t.json "value_json"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["custom_field_definition_id", "target_type", "target_id"], name: "index_custom_field_values_on_definition_and_target", unique: true
    t.index ["custom_field_definition_id"], name: "index_custom_field_values_on_custom_field_definition_id"
    t.index ["target_type", "target_id"], name: "index_custom_field_values_on_target_type_and_target_id"
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
    t.index ["comment_id"], name: "index_notifications_on_comment_id"
    t.index ["event_id"], name: "index_notifications_on_event_id"
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
    t.index ["customer_id"], name: "index_posts_on_customer_id"
  end

  create_table "projects", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.bigint "customer_id", null: false
    t.string "title"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.index ["customer_id"], name: "index_requests_on_customer_id"
    t.index ["event_id"], name: "index_requests_on_event_id"
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
    t.index ["event_id"], name: "index_songs_on_event_id"
  end

  create_table "workspace_memberships", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "customer_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "joined_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_id"], name: "index_workspace_memberships_on_customer_id"
    t.index ["workspace_id", "customer_id"], name: "index_workspace_memberships_on_workspace_id_and_customer_id", unique: true
    t.index ["workspace_id"], name: "index_workspace_memberships_on_workspace_id"
  end

  create_table "workspace_role_assignments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "workspace_membership_id", null: false
    t.bigint "workspace_role_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["workspace_membership_id", "workspace_role_id"], name: "index_workspace_role_assignments_on_membership_and_role", unique: true
    t.index ["workspace_membership_id"], name: "index_workspace_role_assignments_on_workspace_membership_id"
    t.index ["workspace_role_id"], name: "index_workspace_role_assignments_on_workspace_role_id"
  end

  create_table "workspace_roles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "role_key", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "system_role", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["workspace_id", "role_key"], name: "index_workspace_roles_on_workspace_id_and_role_key", unique: true
    t.index ["workspace_id"], name: "index_workspace_roles_on_workspace_id"
  end

  create_table "workspaces", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "industry_code"
    t.json "settings"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "customers"
  add_foreign_key "applications", "customers"
  add_foreign_key "applications", "workspaces"
  add_foreign_key "approvals", "applications"
  add_foreign_key "approvals", "customers", column: "reviewer_id"
  add_foreign_key "categories", "workspaces"
  add_foreign_key "category_assignments", "categories"
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
  add_foreign_key "custom_field_definitions", "workspaces"
  add_foreign_key "custom_field_values", "custom_field_definitions"
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
  add_foreign_key "likes", "customers"
  add_foreign_key "likes", "posts"
  add_foreign_key "member_profiles", "customers"
  add_foreign_key "messages", "customers"
  add_foreign_key "messages", "posts"
  add_foreign_key "permits", "communities"
  add_foreign_key "permits", "customers"
  add_foreign_key "posts", "customers"
  add_foreign_key "projects", "communities"
  add_foreign_key "projects", "customers"
  add_foreign_key "requests", "customers"
  add_foreign_key "requests", "events"
  add_foreign_key "song_customers", "customers"
  add_foreign_key "song_customers", "songs"
  add_foreign_key "songs", "events"
  add_foreign_key "workspace_memberships", "customers"
  add_foreign_key "workspace_memberships", "workspaces"
  add_foreign_key "workspace_role_assignments", "workspace_memberships"
  add_foreign_key "workspace_role_assignments", "workspace_roles"
  add_foreign_key "workspace_roles", "workspaces"
end
