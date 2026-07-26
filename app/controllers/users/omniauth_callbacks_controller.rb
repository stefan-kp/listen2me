module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      was_signed_in = user_signed_in?
      auth = request.env["omniauth.auth"]
      result = GoogleAuthentication.call(
        auth:,
        current_user: (current_user if was_signed_in),
        locale: I18n.locale
      )

      if result.success?
        complete_authentication(result, auth:, was_signed_in:)
      else
        redirect_to authentication_failure_path,
          alert: t("google_auth.errors.#{result.status}")
      end
    end

    def failure
      redirect_to authentication_failure_path,
        alert: t("google_auth.errors.failure")
    end

    private

    def complete_authentication(result, auth:, was_signed_in:)
      if was_signed_in
        GoogleReauthentication.mark!(session:, user: result.user, auth:)
        redirect_to google_reauthentication_return_path,
          notice: t("google_auth.success.#{result.status == :linked ? 'linked' : 'confirmed'}")
      else
        flash[:notice] = t("google_auth.success.signed_in")
        sign_in result.user, event: :authentication
        GoogleReauthentication.mark!(session:, user: result.user, auth:)
        redirect_to after_sign_in_path_for(result.user)
      end
    end

    def google_reauthentication_return_path
      return edit_user_registration_path(locale: I18n.locale) if account_edit_origin?

      settings_path(locale: I18n.locale, settings_section: "account")
    end

    def authentication_failure_path
      return new_user_session_path(locale: I18n.locale) unless user_signed_in?

      google_reauthentication_return_path
    end

    def account_edit_origin?
      URI.parse(request.env["omniauth.origin"].to_s).path == edit_user_registration_path(locale: nil)
    rescue URI::InvalidURIError
      false
    end
  end
end
