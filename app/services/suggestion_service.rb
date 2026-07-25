class SuggestionService
  SUGGESTION_COUNT = 3
  MAX_SUGGESTION_LENGTH = 160
  DEFAULT_MODEL_PROFILE = "fast"
  SUMMARY_MODEL_PROFILE = "cheap"
  FALLBACK_SUGGESTIONS = {
    "de" => [
      { "content" => "Ja, bitte." },
      { "content" => "Nein, danke." },
      { "content" => "Einen Moment, bitte." }
    ],
    "en" => [
      { "content" => "Yes, please." },
      { "content" => "No, thank you." },
      { "content" => "One moment, please." }
    ]
  }.freeze

  attr_reader :last_message

  def initialize(conversation, client: LiteLlm::Client.new)
    @conversation = conversation
    @user = conversation&.user
    @client = client
  end

  def generate_suggestions
    return fallback_suggestions unless proxy_available?

    completion = @client.chat(
      messages: format_conversation_history,
      profile: suggestion_model_profile,
      temperature: 0.3,
      max_tokens: 180,
      response_format: { type: "json_object" }
    )

    parse_suggestions(completion) || fallback_suggestions
  rescue StandardError => e
    Rails.logger.warn "Suggestion generation failed (#{e.class})"
    fallback_suggestions
  end

  def generate_conversation_summary
    return if @user.nil? || !proxy_available?

    conversation_data = prepare_conversation_data
    response = @client.chat(
      messages: [
        { role: "system", content: build_summary_prompt },
        { role: "user", content: conversation_data.to_json }
      ],
      profile: SUMMARY_MODEL_PROFILE,
      temperature: 0.2,
      max_tokens: 600
    )
    return if response.blank?

    @user.update!(
      conversation_summary: response,
      summary_generated_at: Time.current
    )

    response
  rescue StandardError => e
    Rails.logger.warn "Conversation summary generation failed (#{e.class})"
    nil
  end

  private

  def proxy_available?
    @conversation.present? && @user.present? && @client.configured?
  end

  def suggestion_model_profile
    profile = @user.suggestion_model_profile.to_s
    User::SUGGESTION_MODEL_PROFILES.include?(profile) ? profile : DEFAULT_MODEL_PROFILE
  end

  def format_conversation_history
    initial_sentence = @conversation.initial_sentence
    conversation_messages = @conversation.messages
      .order(created_at: :desc)
      .limit(20)
      .to_a
      .reverse
    latest_message = conversation_messages.pop

    user_message = {
      context: conversation_messages.map { |message| serialize_message(message) },
      last_message: latest_message ? serialize_message(latest_message) : initial_sentence_payload(initial_sentence),
      category: initial_sentence&.category&.name,
      user_description: @user.description.to_s.first(2_000),
      summary: @user.conversation_summary.to_json.first(4_000)
    }

    @last_message = user_message[:last_message]

    [
      { role: "system", content: I18n.t("suggestions.system_prompt") },
      { role: "user", content: user_message.to_json }
    ]
  end

  def serialize_message(message)
    {
      role: message.speaker? ? "speaker" : "partner",
      content: message.content
    }
  end

  def initial_sentence_payload(initial_sentence)
    return if initial_sentence&.content.blank?

    {
      role: "speaker",
      content: initial_sentence.content
    }
  end

  def parse_suggestions(completion)
    parsed = JSON.parse(completion.to_s)
    return unless parsed.is_a?(Hash) && parsed.keys == [ "response" ]

    suggestions = parsed.fetch("response")
    return unless suggestions.is_a?(Array) && suggestions.size == SUGGESTION_COUNT

    normalized = suggestions.map do |suggestion|
      return unless suggestion.is_a?(Hash) && suggestion.keys == [ "content" ]

      content = suggestion.fetch("content")
      return unless content.is_a?(String)

      content = content.strip
      return unless content.present? && content.length <= MAX_SUGGESTION_LENGTH

      { "content" => content }
    end

    return unless normalized.map { |suggestion| suggestion.fetch("content") }.uniq.size == SUGGESTION_COUNT

    normalized
  rescue JSON::ParserError, TypeError
    nil
  end

  def fallback_suggestions
    locale = I18n.locale.to_s.start_with?("de") ? "de" : "en"
    FALLBACK_SUGGESTIONS.fetch(locale).map(&:dup)
  end

  def prepare_conversation_data
    @user.conversations.order(created_at: :desc).limit(20).map do |conversation|
      {
        id: conversation.id,
        messages: conversation.messages.order(created_at: :desc).limit(20).reverse.map do |message|
          {
            role: message.role,
            content: message.content,
            created_at: message.created_at
          }
        end
      }
    end
  end

  def build_summary_prompt
    I18n.t("suggestion_service.summary_prompt")
  end
end
