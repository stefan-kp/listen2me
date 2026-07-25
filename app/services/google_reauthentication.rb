require "openssl"

class GoogleReauthentication
  SESSION_KEY = "google_reauthentication"
  MAX_AGE = 5.minutes

  Marker = Data.define(:verified_email_digest) do
    def matches_verified_email?(email)
      GoogleReauthentication.email_matches_digest?(email, verified_email_digest)
    end
  end

  class << self
    def mark!(session:, user:, auth:, now: Time.current)
      attributes = auth.respond_to?(:to_h) ? auth.to_h.deep_stringify_keys : {}
      uid = attributes["uid"].to_s.strip
      email = attributes.dig("info", "email").to_s.strip.downcase

      session.delete(SESSION_KEY)
      return false unless valid_google_identity?(attributes, user:, uid:, email:)

      session[SESSION_KEY] = {
        "user_id" => user.id,
        "google_uid" => uid,
        "verified_email_digest" => email_digest(email),
        "authenticated_at" => now.to_i
      }
      true
    end

    def active?(session:, user:, now: Time.current)
      current(session:, user:, now:).present?
    end

    def current(session:, user:, now: Time.current)
      marker = marker_for(session[SESSION_KEY], user:, now:)
      session.delete(SESSION_KEY) unless marker
      marker
    end

    def consume!(session:, user:, now: Time.current)
      marker = current(session:, user:, now:)
      session.delete(SESSION_KEY)
      marker
    end

    def email_matches_digest?(email, digest)
      candidate = email_digest(email)
      digest.present? && ActiveSupport::SecurityUtils.secure_compare(candidate, digest.to_s)
    end

    private

    def marker_for(raw_marker, user:, now:)
      marker = raw_marker.respond_to?(:to_h) ? raw_marker.to_h.deep_stringify_keys : {}
      uid = marker["google_uid"].to_s
      authenticated_at = marker["authenticated_at"].to_i
      age = now.to_i - authenticated_at

      return unless marker["user_id"].to_i == user.id
      return unless user.google_uid.present? && secure_uid_match?(uid, user.google_uid)
      return unless age.between?(0, MAX_AGE.to_i)
      return unless marker["verified_email_digest"].present?

      Marker.new(verified_email_digest: marker["verified_email_digest"])
    end

    def valid_google_identity?(attributes, user:, uid:, email:)
      verified = attributes.dig("extra", "id_info", "email_verified")
      verified = attributes.dig("extra", "raw_info", "email_verified") if verified.nil?

      attributes["provider"].to_s == GoogleAuthentication::PROVIDER &&
        user.google_uid.present? &&
        secure_uid_match?(uid, user.google_uid) &&
        email.present? &&
        (verified == true || verified == "true")
    end

    def secure_uid_match?(left, right)
      left = left.to_s
      right = right.to_s
      left.bytesize == right.bytesize && ActiveSupport::SecurityUtils.secure_compare(left, right)
    end

    def email_digest(email)
      key = Rails.application.key_generator.generate_key("google-reauthentication-email", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, email.to_s.strip.downcase)
    end
  end
end
