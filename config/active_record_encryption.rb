# frozen_string_literal: true

require "digest"

# Derives environment-specific Active Record Encryption keys without committing secrets.
module Listen2meEncryption
  module_function

  def configure(config, environment:)
    seed = encryption_seed(environment)
    return unless seed

    key = ->(purpose) { Digest::SHA256.hexdigest("#{seed}:#{purpose}") }
    encryption = config.active_record.encryption
    encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", key.call("primary"))
    encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", key.call("deterministic"))
    encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", key.call("salt"))
  end

  def encryption_seed(environment)
    return ENV.fetch("SECRET_KEY_BASE") if ENV.fetch("SECRET_KEY_BASE", "").length.positive?
    return "listen2me-local-development" if environment == :development
    return "listen2me-test" if environment == :test

    "asset-precompile-only" if ENV.fetch("SECRET_KEY_BASE_DUMMY", "").length.positive?
  end
end
