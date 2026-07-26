require "test_helper"

class GoogleAuthenticationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default_user)
    @omniauth_test_mode = OmniAuth.config.test_mode
    @omniauth_mock_auth = OmniAuth.config.mock_auth[:google_oauth2]
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = @omniauth_test_mode
    OmniAuth.config.mock_auth[:google_oauth2] = @omniauth_mock_auth
  end

  test "verified Google callback creates and signs in an onboarding user" do
    assert_difference("User.count", 1) do
      perform_google_oauth(google_auth(uid: "google-new", email: "google-new@example.com"))
    end

    User.find_by!(google_uid: "google-new")
    assert_redirected_to onboarding_path(locale: :de)

    follow_redirect!
    assert_response :success
  end

  test "callback refuses an unauthenticated email collision" do
    assert_no_difference("User.count") do
      perform_google_oauth(google_auth(uid: "google-conflict", email: @user.email))
    end

    assert_redirected_to new_user_session_path(locale: :de)
    follow_redirect!
    assert_response :success
    assert_includes response.body, I18n.t("google_auth.errors.email_conflict", locale: :de)
    assert_nil @user.reload.google_uid
  end

  test "callback links but never replaces the currently signed in user" do
    original_conversation_ids = @user.conversation_ids
    sign_in @user

    perform_google_oauth(google_auth(uid: "google-link", email: @user.email.upcase))

    assert_redirected_to settings_path(locale: :de, settings_section: "account")
    assert_equal "google-link", @user.reload.google_uid
    assert_equal original_conversation_ids, @user.conversation_ids
  end

  test "a failed signed in linking attempt returns to account settings with its error" do
    sign_in @user

    perform_google_oauth(
      google_auth(uid: "google-wrong-email", email: "different@example.com")
    )

    assert_redirected_to settings_path(locale: :de, settings_section: "account")
    follow_redirect!
    assert_response :success
    assert_includes response.body, I18n.t("google_auth.errors.email_mismatch", locale: :de)
    assert_nil @user.reload.google_uid
  end

  test "fresh Google confirmation returns to account editing and replaces the password prompt" do
    @user.update!(google_uid: "google-edit-account")
    sign_in @user

    perform_google_oauth(
      google_auth(uid: "google-edit-account", email: @user.email),
      origin: edit_user_registration_path(locale: :de)
    )

    assert_redirected_to edit_user_registration_path(locale: :de)
    follow_redirect!
    assert_response :success
    assert_select "label[for='user_current_password']", count: 0
    assert_includes response.body, I18n.t("google_auth.reauthentication.active", locale: :de)
  end

  test "unverified callback exposes no provider credentials or raw claims" do
    raw_token = "must-not-appear-in-the-response"
    auth = google_auth(uid: "google-unverified", email: "unsafe@example.com", verified: false)
    auth[:credentials] = { token: raw_token }

    perform_google_oauth(auth)

    assert_redirected_to new_user_session_path(locale: :de)
    follow_redirect!
    assert_response :success
    assert_not_includes response.body, raw_token
    assert_not_includes response.body, "google-unverified"
    assert_includes response.body, I18n.t("google_auth.errors.invalid", locale: :de)
  end

  test "sign in and registration render a POST Google button only when configured" do
    with_google_configuration("client", "secret") do
      [ new_user_session_path(locale: :de), new_user_registration_path(locale: :de) ].each do |path|
        get path
        assert_response :success
        assert_select "form[action*='users/auth/google_oauth2'][method='post'][data-turbo='false']", count: 1
        assert_select "form[action*='users/auth/google_oauth2'] button", text: "Mit Google fortfahren"
      end
    end
  end

  test "missing Google configuration keeps password authentication available and hides the button" do
    with_google_configuration(nil, nil) do
      get new_user_session_path(locale: :de)

      assert_response :success
      assert_select "form[action*='users/auth/google_oauth2']", count: 0
      assert_select "form[action*='users/sign_in'] input[type='password']", count: 1
    end
  end

  test "settings render an explicit POST action for connecting Google" do
    sign_in @user

    with_google_configuration("client", "secret") do
      get settings_path(locale: :de, settings_section: "account")

      assert_response :success
      assert_includes response.body, I18n.t("google_auth.settings.not_connected", locale: :de)
      assert_select "form[action*='users/auth/google_oauth2'][method='post'][data-turbo='false']", count: 1
      assert_select "form[action*='users/auth/google_oauth2'] button", text: I18n.t("google_auth.settings.connect", locale: :de)
    end
  end

  test "provider failure returns a generic localized message" do
    perform_google_oauth(:invalid_credentials)

    assert_redirected_to new_user_session_path(locale: :de)
    follow_redirect!
    assert_response :success
    assert_includes response.body, I18n.t("google_auth.errors.failure", locale: :de)
  end

  test "a new Google user can set a known password once after authentication" do
    perform_google_oauth(google_auth(uid: "google-password-setup", email: "setup@example.com"))
    user = User.find_by!(google_uid: "google-password-setup")

    put user_registration_path(locale: :de), params: {
      user: {
        first_name: "Neuer",
        last_name: "Name",
        email: user.email,
        password: "new-password-123",
        password_confirmation: "new-password-123"
      }
    }

    assert_redirected_to settings_path(locale: :de, settings_section: "account")
    assert_equal "Neuer", user.reload.first_name
    assert user.valid_password?("new-password-123")

    put user_registration_path(locale: :de), params: {
      user: {
        first_name: "Second",
        last_name: user.last_name,
        email: user.email
      }
    }

    assert_response :unprocessable_entity
    assert_equal "Neuer", user.reload.first_name
  end

  test "Google confirmation only permits its freshly verified email address" do
    perform_google_oauth(google_auth(uid: "google-email-guard", email: "verified@example.com"))
    user = User.find_by!(google_uid: "google-email-guard")

    put user_registration_path(locale: :de), params: {
      user: {
        first_name: user.first_name,
        last_name: user.last_name,
        email: "different@example.com"
      }
    }

    assert_response :unprocessable_entity
    assert_equal "verified@example.com", user.reload.email
    assert_includes response.body, I18n.t("google_auth.reauthentication.email_mismatch", locale: :de)

    put user_registration_path(locale: :de), params: {
      user: {
        first_name: "Still verified",
        last_name: user.last_name,
        email: "verified@example.com"
      }
    }

    assert_redirected_to settings_path(locale: :de, settings_section: "account")
    assert_equal "Still verified", user.reload.first_name
  end

  test "password accounts still update with their current password" do
    sign_in @user

    put user_registration_path(locale: :de), params: {
      user: {
        first_name: "Updated",
        last_name: @user.last_name,
        email: @user.email,
        current_password: "password123"
      }
    }

    assert_redirected_to settings_path(locale: :de, settings_section: "account")
    assert_equal "Updated", @user.reload.first_name
  end

  test "a linked account requires fresh Google confirmation before changing email" do
    @user.update!(google_uid: "google-linked-password-account")
    sign_in @user

    put user_registration_path(locale: :de), params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        email: "unconfirmed-change@example.com",
        current_password: "password123"
      }
    }

    assert_response :unprocessable_entity
    assert_equal "test@example.com", @user.reload.email
    assert_includes response.body,
      I18n.t("google_auth.reauthentication.email_confirmation_required", locale: :de)
  end

  private

  def google_auth(uid:, email:, verified: true)
    {
      provider: "google_oauth2",
      uid:,
      info: {
        email:,
        first_name: "Google",
        last_name: "User"
      },
      extra: {
        id_info: { email_verified: verified }
      }
    }
  end

  def perform_google_oauth(auth, origin: nil)
    OmniAuth.config.mock_auth[:google_oauth2] = if auth.is_a?(Symbol)
      auth
    else
      OmniAuth::AuthHash.new(auth)
    end

    post user_google_oauth2_omniauth_authorize_path(origin:)
    assert_response :redirect

    while response.redirect? && URI.parse(response.location).path.start_with?("/users/auth/")
      follow_redirect!
    end
  end

  def with_google_configuration(client_id, client_secret)
    original_client_id = ENV["GOOGLE_CLIENT_ID"]
    original_client_secret = ENV["GOOGLE_CLIENT_SECRET"]
    ENV["GOOGLE_CLIENT_ID"] = client_id
    ENV["GOOGLE_CLIENT_SECRET"] = client_secret
    yield
  ensure
    ENV["GOOGLE_CLIENT_ID"] = original_client_id
    ENV["GOOGLE_CLIENT_SECRET"] = original_client_secret
  end
end
