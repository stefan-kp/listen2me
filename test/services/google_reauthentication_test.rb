require "test_helper"

class GoogleReauthenticationTest < ActiveSupport::TestCase
  setup do
    @user = users(:default_user)
    @user.update!(google_uid: "google-reauth-user")
    @session = {}
    @now = Time.zone.parse("2026-07-25 20:00:00")
  end

  test "a verified marker is bound to the user and Google uid and consumed once" do
    assert GoogleReauthentication.mark!(
      session: @session,
      user: @user,
      auth: google_auth,
      now: @now
    )
    assert GoogleReauthentication.active?(session: @session, user: @user, now: @now + 4.minutes)

    marker = GoogleReauthentication.consume!(session: @session, user: @user, now: @now + 4.minutes)
    assert marker.matches_verified_email?(@user.email.upcase)
    assert_not marker.matches_verified_email?("other@example.com")
    assert_nil GoogleReauthentication.consume!(session: @session, user: @user, now: @now + 4.minutes)
  end

  test "an expired marker is rejected and removed" do
    GoogleReauthentication.mark!(session: @session, user: @user, auth: google_auth, now: @now)

    assert_nil GoogleReauthentication.consume!(
      session: @session,
      user: @user,
      now: @now + 5.minutes + 1.second
    )
    assert_empty @session
  end

  test "a marker for another user or changed Google uid is rejected" do
    GoogleReauthentication.mark!(session: @session, user: @user, auth: google_auth, now: @now)
    assert_nil GoogleReauthentication.consume!(session: @session, user: users(:other_user), now: @now)

    GoogleReauthentication.mark!(session: @session, user: @user, auth: google_auth, now: @now)
    @user.update!(google_uid: "different-google-uid")
    assert_nil GoogleReauthentication.consume!(session: @session, user: @user, now: @now)
  end

  test "unverified claims create no marker and provider credentials are never stored" do
    auth = google_auth
    auth[:extra][:id_info][:email_verified] = false
    auth[:credentials] = { token: "provider-secret", refresh_token: "provider-refresh" }

    assert_not GoogleReauthentication.mark!(session: @session, user: @user, auth:, now: @now)
    assert_empty @session

    auth[:extra][:id_info][:email_verified] = true
    assert GoogleReauthentication.mark!(session: @session, user: @user, auth:, now: @now)
    assert_not_includes @session.inspect, "provider-secret"
    assert_not_includes @session.inspect, "provider-refresh"
    assert_not_includes @session.inspect, @user.email
  end

  private

  def google_auth
    {
      provider: "google_oauth2",
      uid: @user.google_uid,
      info: { email: @user.email },
      extra: { id_info: { email_verified: true } }
    }
  end
end
