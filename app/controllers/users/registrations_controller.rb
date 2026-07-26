module Users
  class RegistrationsController < Devise::RegistrationsController
    helper_method :google_reauthentication_active?

    protected

    def update_resource(resource, params)
      marker = GoogleReauthentication.current(session:, user: resource)
      return reject_unconfirmed_google_email_change(resource, params) if marker.nil? && google_email_changed?(resource, params[:email])
      return super unless marker

      attributes = params.to_h.stringify_keys
      attributes.delete("current_password")

      unless google_email_change_allowed?(resource, attributes["email"], marker)
        resource.assign_attributes(attributes.except("password", "password_confirmation"))
        resource.errors.add(:email, I18n.t("google_auth.reauthentication.email_mismatch"))
        return false
      end

      remove_blank_passwords(attributes)
      updated = resource.update(attributes)
      GoogleReauthentication.consume!(session:, user: resource) if updated
      updated
    end

    def after_update_path_for(_resource)
      settings_path(locale: I18n.locale, settings_section: "account")
    end

    def google_reauthentication_active?
      GoogleReauthentication.active?(session:, user: resource)
    end

    private

    def google_email_changed?(resource, candidate_email)
      resource.google_connected? && !candidate_email.to_s.strip.casecmp?(resource.email.to_s.strip)
    end

    def reject_unconfirmed_google_email_change(resource, params)
      attributes = params.to_h.stringify_keys
      resource.assign_attributes(attributes.except("password", "password_confirmation", "current_password"))
      resource.errors.add(:email, I18n.t("google_auth.reauthentication.email_confirmation_required"))
      false
    end

    def google_email_change_allowed?(resource, candidate_email, marker)
      return true if candidate_email.to_s.strip.casecmp?(resource.email.to_s.strip)

      marker.matches_verified_email?(candidate_email)
    end

    def remove_blank_passwords(attributes)
      return if attributes["password"].present? || attributes["password_confirmation"].present?

      attributes.delete("password")
      attributes.delete("password_confirmation")
    end
  end
end
