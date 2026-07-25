module Voice
  class UsageBudget
    DEFAULT_LIMITS = {
      "cartesia" => 500,
      "elevenlabs" => 300
    }.freeze
    FALLBACK_CACHE = ActiveSupport::Cache::MemoryStore.new

    def self.consume!(provider:, characters:, cache: budget_cache)
      limit = limit_for(provider)
      raise BudgetExceededError.new(provider:, message: "Speech provider is disabled") if limit <= 0

      key = "listen2me/voice-budget/#{Date.current.iso8601}/#{provider}"
      used = cache.increment(key, characters, expires_in: 2.days)
      unless used
        raise BudgetExceededError.new(provider:, message: "Speech budget store unavailable")
      end

      if used > limit
        cache.decrement(key, characters)
        raise BudgetExceededError.new(provider:, message: "Daily speech budget reached")
      end
    end

    def self.limit_for(provider)
      default = DEFAULT_LIMITS.fetch(provider.to_s, 0)
      ENV.fetch("#{provider.to_s.upcase}_DAILY_CHARACTER_LIMIT", default.to_s).to_i.clamp(0, 100_000)
    end

    def self.enabled?(provider)
      limit_for(provider).positive?
    end

    def self.budget_cache
      Rails.cache.is_a?(ActiveSupport::Cache::NullStore) ? FALLBACK_CACHE : Rails.cache
    end
  end
end
