require "test_helper"

class Voice::SpeechOutputTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls

    def initialize(name:, chunks: [], error: nil, configured: true)
      @name = name
      @chunks = chunks
      @error = error
      @configured = configured
      @calls = 0
    end

    def configured?
      @configured
    end

    def cache_identity(language:)
      "#{@name}:voice:#{language}"
    end

    def stream(text:, language:)
      @calls += 1
      @chunks.each { |chunk| yield chunk }
      raise @error if @error
    end
  end

  setup do
    @user = users(:default_user)
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  test "uses OpenAI directly and caches repeated identical speech" do
    openai = FakeClient.new(name: "openai", chunks: [ "pcm", "bytes" ])
    service = build_service("openai", "openai" => openai)

    first = collect(service, "Ja, bitte.")
    second = collect(service, "Ja, bitte.")

    assert_equal "pcmbytes", first
    assert_equal first, second
    assert_equal 1, openai.calls
  end

  test "falls from an explicitly selected alternative to OpenAI before audio starts" do
    cartesia = FakeClient.new(
      name: "cartesia",
      error: Voice::ProviderError.new(provider: "cartesia", status: 429)
    )
    openai = FakeClient.new(name: "openai", chunks: [ "openai-pcm" ])
    service = build_service("cartesia", "cartesia" => cartesia, "openai" => openai)

    assert_equal "openai-pcm", collect(service, "Hallo")
    assert_equal 1, cartesia.calls
    assert_equal 1, openai.calls
  end

  test "never spends an alternative provider when OpenAI was selected" do
    openai = FakeClient.new(name: "openai", chunks: [ "primary" ])
    cartesia = FakeClient.new(name: "cartesia", chunks: [ "must-not-run" ])
    service = build_service("openai", "openai" => openai, "cartesia" => cartesia)

    assert_equal "primary", collect(service, "Hallo")
    assert_equal 0, cartesia.calls
  end

  test "does not repeat a sentence through another provider after partial audio" do
    cartesia = FakeClient.new(
      name: "cartesia",
      chunks: [ "partial" ],
      error: Voice::ProviderError.new(provider: "cartesia")
    )
    openai = FakeClient.new(name: "openai", chunks: [ "duplicate" ])
    service = build_service("cartesia", "cartesia" => cartesia, "openai" => openai)
    audio = String.new

    assert_raises Voice::UnavailableError do
      service.stream(text: "Nicht doppelt sprechen") { |chunk| audio << chunk }
    end

    assert_equal "partial", audio
    assert_equal 0, openai.calls
  end

  test "daily alternative budget is conservative" do
    cache = ActiveSupport::Cache::MemoryStore.new

    Voice::UsageBudget.consume!(provider: "cartesia", characters: 490, cache:)
    assert_raises Voice::BudgetExceededError do
      Voice::UsageBudget.consume!(provider: "cartesia", characters: 20, cache:)
    end
    Voice::UsageBudget.consume!(provider: "cartesia", characters: 10, cache:)
  end

  test "alternative budget is atomic across concurrent demo requests" do
    cache = ActiveSupport::Cache::MemoryStore.new
    results = 20.times.map do
      Thread.new do
        Voice::UsageBudget.consume!(provider: "cartesia", characters: 30, cache:)
        :accepted
      rescue Voice::BudgetExceededError
        :rejected
      end
    end.map(&:value)

    assert_equal 16, results.count(:accepted)
    assert_equal 4, results.count(:rejected)
    Voice::UsageBudget.consume!(provider: "cartesia", characters: 20, cache:)
    assert_raises(Voice::BudgetExceededError) do
      Voice::UsageBudget.consume!(provider: "cartesia", characters: 1, cache:)
    end
  end

  test "zero limit disables an alternative provider" do
    previous = ENV["CARTESIA_DAILY_CHARACTER_LIMIT"]
    ENV["CARTESIA_DAILY_CHARACTER_LIMIT"] = "0"

    assert_raises(Voice::BudgetExceededError) do
      Voice::UsageBudget.consume!(
        provider: "cartesia",
        characters: 1,
        cache: ActiveSupport::Cache::MemoryStore.new
      )
    end
  ensure
    ENV["CARTESIA_DAILY_CHARACTER_LIMIT"] = previous
  end

  test "disabled alternative never reaches voice discovery or speech" do
    previous = ENV["CARTESIA_DAILY_CHARACTER_LIMIT"]
    ENV["CARTESIA_DAILY_CHARACTER_LIMIT"] = "0"
    cartesia = FakeClient.new(name: "cartesia", chunks: [ "must-not-run" ])
    openai = FakeClient.new(name: "openai", chunks: [ "primary" ])
    service = build_service("cartesia", "cartesia" => cartesia, "openai" => openai)

    assert_equal "primary", collect(service, "Hallo")
    assert_equal 0, cartesia.calls
    assert_equal 1, openai.calls
  ensure
    ENV["CARTESIA_DAILY_CHARACTER_LIMIT"] = previous
  end

  private

  def build_service(provider, clients)
    Voice::SpeechOutput.new(
      user: @user,
      provider:,
      locale: :de,
      clients:,
      cache: @cache
    )
  end

  def collect(service, text)
    audio = String.new
    service.stream(text:) { |chunk| audio << chunk }
    audio
  end
end
