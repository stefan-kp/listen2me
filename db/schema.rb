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

ActiveRecord::Schema[8.1].define(version: 2026_07_25_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon_name", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.bigint "initial_sentence_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["initial_sentence_id"], name: "index_conversations_on_initial_sentence_id"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "languages", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.integer "role"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "sentences", force: :cascade do |t|
    t.bigint "category_id"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "language_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_sentences_on_category_id"
    t.index ["language_id"], name: "index_sentences_on_language_id"
    t.index ["user_id"], name: "index_sentences_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.jsonb "conversation_summary"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "elevenlabs_api_key"
    t.string "elevenlabs_voice_id"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "google_uid"
    t.string "last_name"
    t.string "llm_api_key"
    t.string "llm_model", default: "gpt-4o"
    t.string "llm_provider", default: "openai"
    t.datetime "onboarding_completed_at"
    t.string "preferred_locale", default: "de", null: false
    t.string "preferred_speech_mode", default: "direct", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "speech_provider", default: "openai", null: false
    t.string "suggestion_model_profile", default: "fast", null: false
    t.datetime "summary_generated_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid_unique", unique: true, where: "(google_uid IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["summary_generated_at"], name: "index_users_on_summary_generated_at"
    t.check_constraint "google_uid IS NULL OR btrim(google_uid::text) <> ''::text", name: "users_google_uid_not_blank"
    t.check_constraint "speech_provider::text = ANY (ARRAY['openai'::character varying::text, 'browser'::character varying::text, 'cartesia'::character varying::text, 'elevenlabs'::character varying::text])", name: "users_speech_provider_check"
    t.check_constraint "suggestion_model_profile::text = ANY (ARRAY['fast'::character varying::text, 'cheap'::character varying::text])", name: "users_suggestion_model_profile_check"
  end

  add_foreign_key "categories", "users", on_delete: :cascade
  add_foreign_key "conversations", "sentences", column: "initial_sentence_id", on_delete: :nullify
  add_foreign_key "conversations", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "sentences", "categories"
  add_foreign_key "sentences", "languages"
  add_foreign_key "sentences", "users"
end
