class SuggestionService
  SUPPORTED_PROVIDERS = %w[openai anthropic gemini].freeze
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

  def initialize(conversation)
    @conversation = conversation
    @user = conversation&.user
  end

  def generate_suggestions
    return fallback_suggestions unless llm_configured?

    response = llm.chat(
      messages: format_conversation_history,
      response_format: { type: "json_object" }
    )

    parse_suggestions(response&.completion) || fallback_suggestions
  rescue StandardError => e
    Rails.logger.warn "Suggestion generation failed (#{e.class})"
    fallback_suggestions
  end

  def generate_conversation_summary
    return if @user.nil? || !llm_configured?

    conversation_data = prepare_conversation_data
    prompt = build_summary_prompt
    response = call_llm_with_prompt(prompt, conversation_data)
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

  def llm_configured?
    @conversation.present? &&
      @user.present? &&
      @user.llm_api_key.present? &&
      SUPPORTED_PROVIDERS.include?(@user.llm_provider.to_s)
  end

  def llm
    klass = case @user.llm_provider
    when "openai"
      Langchain::LLM::OpenAI
    when "anthropic"
      Langchain::LLM::Anthropic
    when "gemini"
      Langchain::LLM::GoogleGemini
    end

    klass.new(
      api_key: @user.llm_api_key,
      default_options: {
        temperature: 0.7,
        chat_model: @user.llm_model
      }
    )
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
    suggestions = parsed.is_a?(Hash) ? parsed["response"] : parsed
    return unless suggestions.is_a?(Array)

    normalized = suggestions.filter_map do |suggestion|
      content = suggestion.is_a?(Hash) ? suggestion["content"] || suggestion[:content] : suggestion
      { "content" => content.to_s.strip } if content.present?
    end.first(3)

    normalized if normalized.size == 3
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

  def call_llm_with_prompt(prompt, data)
    client = create_llm_client

    case @user.llm_provider
    when "openai"
      response = client.chat(
        parameters: {
          model: @user.llm_model || "gpt-4",
          messages: [
            { role: "system", content: prompt },
            { role: "user", content: data.to_json }
          ],
          temperature: 0.7
        }
      )
      response.dig("choices", 0, "message", "content")
    when "anthropic"
      response = client.messages(
        model: @user.llm_model || "claude-3-opus-20240229",
        messages: [ { role: "user", content: "#{prompt}\n\nConversations:\n#{data.to_json}" } ],
        temperature: 0.7
      )
      response.content.first.text
    when "gemini"
      response = client.generate_content(
        "#{prompt}\n\nConversations:\n#{data.to_json}",
        temperature: 0.7
      )
      response.text
    end
  end

  def create_llm_client
    case @user.llm_provider
    when "openai"
      OpenAI::Client.new(access_token: @user.llm_api_key)
    when "anthropic"
      Anthropic::Client.new(access_token: @user.llm_api_key)
    when "gemini"
      Google::Gemini::Client.new(access_token: @user.llm_api_key)
    end
  end
end
