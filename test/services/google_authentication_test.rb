require "test_helper"

class GoogleAuthenticationTest < ActiveSupport::TestCase
  setup do
    @user = users(:default_user)
    @other_user = users(:other_user)
  end

  test "creates one isolated onboarding account from a verified Google identity" do
    result = nil

    assert_difference("User.count", 1) do
      result = GoogleAuthentication.call(
        auth: google_auth(uid: "google-new-user", email: "new-user@example.com"),
        locale: :en
      )
    end

    assert_equal :created, result.status
    assert result.success?
    assert_equal "google-new-user", result.user.google_uid
    assert_equal "new-user@example.com", result.user.email
    assert_equal "Google", result.user.first_name
    assert_equal "User", result.user.last_name
    assert_equal "en", result.user.preferred_locale
    assert result.user.encrypted_password.present?
    assert_not result.user.onboarding_completed?
    assert result.user.categories.exists?
  end

  test "finds repeat sign-ins only by Google uid and keeps local profile data" do
    @user.update!(google_uid: "google-existing-user")

    result = GoogleAuthentication.call(
      auth: google_auth(
        uid: "google-existing-user",
        email: "changed@example.com",
        first_name: "Changed",
        last_name: "Claim"
      )
    )

    assert_equal :signed_in, result.status
    assert_equal @user, result.user
    assert_equal "test@example.com", @user.reload.email
    assert_equal "Test", @user.first_name
    assert_equal "User", @user.last_name
  end

  test "signs in an existing Google identity without requiring profile names" do
    @user.update!(google_uid: "google-single-name-user")

    result = GoogleAuthentication.call(
      auth: google_auth(
        uid: "google-single-name-user",
        email: @user.email,
        first_name: "",
        last_name: ""
      )
    )

    assert_equal :signed_in, result.status
    assert_equal @user, result.user
  end

  test "never takes over a password account solely because its email matches" do
    result = nil

    assert_no_difference("User.count") do
      result = GoogleAuthentication.call(
        auth: google_auth(uid: "unlinked-google-user", email: @user.email.upcase)
      )
    end

    assert_equal :email_conflict, result.status
    assert_not result.success?
    assert_nil @user.reload.google_uid
  end

  test "links an explicitly authenticated account only when verified emails match" do
    result = GoogleAuthentication.call(
      auth: google_auth(
        uid: "google-link",
        email: @user.email.upcase,
        first_name: "",
        last_name: ""
      ),
      current_user: @user
    )

    assert_equal :linked, result.status
    assert result.linked?
    assert_equal "google-link", @user.reload.google_uid
  end

  test "rejects an email mismatch while linking" do
    result = GoogleAuthentication.call(
      auth: google_auth(uid: "google-wrong-email", email: "wrong@example.com"),
      current_user: @user
    )

    assert_equal :email_mismatch, result.status
    assert_nil @user.reload.google_uid
  end

  test "never links an identity belonging to another user or replaces a linked identity" do
    @other_user.update!(google_uid: "google-other-user")

    identity_conflict = GoogleAuthentication.call(
      auth: google_auth(uid: "google-other-user", email: @user.email),
      current_user: @user
    )
    assert_equal :identity_conflict, identity_conflict.status

    @user.update!(google_uid: "google-current-user")
    already_connected = GoogleAuthentication.call(
      auth: google_auth(uid: "google-replacement", email: @user.email),
      current_user: @user
    )
    assert_equal :already_connected, already_connected.status
    assert_equal "google-current-user", @user.reload.google_uid
  end

  test "rejects unverified malformed and incomplete identities atomically" do
    invalid_auths = [
      google_auth(uid: "unverified", email: "unverified@example.com", verified: false),
      google_auth(uid: "", email: "missing-uid@example.com"),
      google_auth(uid: "missing-email", email: ""),
      google_auth(uid: "missing-first-name", email: "first@example.com", first_name: ""),
      google_auth(uid: "missing-last-name", email: "last@example.com", last_name: ""),
      google_auth(uid: "wrong-provider", email: "provider@example.com").merge(provider: "other")
    ]

    assert_no_difference([ "User.count", "Category.count", "Sentence.count" ]) do
      invalid_auths.each do |auth|
        result = GoogleAuthentication.call(auth:)
        assert_equal :invalid, result.status
      end
    end
  end

  test "database and model prevent duplicate or blank Google identities" do
    @user.update!(google_uid: "google-unique")
    @other_user.google_uid = "google-unique"
    assert_not @other_user.valid?
    assert @other_user.errors.of_kind?(:google_uid, :taken)

    @other_user.google_uid = ""
    assert_not @other_user.valid?
    assert @other_user.errors.of_kind?(:google_uid, :blank)
  end

  private

  def google_auth(
    uid:,
    email:,
    verified: true,
    first_name: "Google",
    last_name: "User"
  )
    {
      provider: "google_oauth2",
      uid:,
      info: {
        email:,
        first_name:,
        last_name:
      },
      extra: {
        id_info: { email_verified: verified }
      }
    }
  end
end
