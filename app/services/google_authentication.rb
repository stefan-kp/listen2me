class GoogleAuthentication
  PROVIDER = "google_oauth2"
  MAX_UID_LENGTH = 255

  Result = Data.define(:status, :user) do
    def success?
      %i[signed_in created linked already_linked].include?(status)
    end

    def linked?
      %i[linked already_linked].include?(status)
    end
  end

  def self.call(...)
    new(...).call
  end

  def initialize(auth:, current_user: nil, locale: I18n.default_locale)
    @auth = auth.respond_to?(:to_h) ? auth.to_h.deep_stringify_keys : {}
    @current_user = current_user
    @locale = locale.to_s
  end

  def call
    return result(:invalid) unless valid_identity_claims?

    @current_user ? link_current_user : find_or_create_user
  end

  private

  def link_current_user
    identity_user = User.find_by(google_uid: uid)
    return result(:already_linked, @current_user) if identity_user == @current_user
    return result(:identity_conflict) if identity_user.present?
    return result(:email_mismatch) unless same_email?(@current_user.email, email)

    @current_user.with_lock do
      @current_user.reload
      return result(:already_linked, @current_user) if @current_user.google_uid == uid
      return result(:already_connected) if @current_user.google_uid.present?

      @current_user.update!(google_uid: uid)
    end

    result(:linked, @current_user)
  rescue ActiveRecord::RecordNotUnique
    resolve_link_race
  end

  def find_or_create_user
    identity_user = User.find_by(google_uid: uid)
    return result(:signed_in, identity_user) if identity_user
    return result(:email_conflict) if user_with_email
    return result(:invalid) unless valid_profile_claims?

    user = User.transaction(requires_new: true) do
      User.create!(
        email:,
        first_name:,
        last_name:,
        google_uid: uid,
        password: Devise.friendly_token.first(32),
        preferred_locale:
      )
    end

    result(:created, user)
  rescue ActiveRecord::RecordNotUnique
    resolve_create_race
  rescue ActiveRecord::RecordInvalid
    result(:invalid)
  end

  def resolve_link_race
    identity_user = User.find_by(google_uid: uid)
    return result(:already_linked, @current_user) if identity_user == @current_user

    result(:identity_conflict)
  end

  def resolve_create_race
    identity_user = User.find_by(google_uid: uid)
    return result(:signed_in, identity_user) if identity_user

    result(:email_conflict)
  end

  def valid_identity_claims?
    provider == PROVIDER &&
      uid.present? &&
      uid.length <= MAX_UID_LENGTH &&
      email.present? &&
      email_verified?
  end

  def valid_profile_claims?
    first_name.present? && last_name.present?
  end

  def provider
    @auth["provider"].to_s
  end

  def uid
    @uid ||= @auth["uid"].to_s.strip
  end

  def email
    @email ||= @auth.dig("info", "email").to_s.strip.downcase
  end

  def first_name
    @first_name ||= (
      @auth.dig("info", "first_name").presence ||
      @auth.dig("extra", "raw_info", "given_name")
    ).to_s.strip
  end

  def last_name
    @last_name ||= (
      @auth.dig("info", "last_name").presence ||
      @auth.dig("extra", "raw_info", "family_name")
    ).to_s.strip
  end

  def email_verified?
    value = @auth.dig("extra", "id_info", "email_verified")
    value = @auth.dig("extra", "raw_info", "email_verified") if value.nil?
    value == true || value == "true"
  end

  def user_with_email
    @user_with_email ||= User.where("LOWER(email) = ?", email).first
  end

  def same_email?(left, right)
    left.to_s.strip.casecmp?(right.to_s.strip)
  end

  def preferred_locale
    User::PREFERRED_LOCALES.include?(@locale) ? @locale : I18n.default_locale.to_s
  end

  def result(status, user = nil)
    Result.new(status:, user:)
  end
end
