# For optimal performance, the Conversation object passed to this service
# should be preloaded with the following associations:
#   conversation = Conversation.includes(:messages, :user, initial_sentence: [:category]).find(id)
#   SuggestionService.new(conversation)
class SuggestionService
  attr_reader :last_message
  def initialize(conversation)
    @conversation = conversation
    @user = conversation.user
    @llm_provider = @user.llm_provider # Store for convenience
    @api_key = @user.llm_api_key # Get API key from user attribute

    # It's good practice to check if the api_key is present,
    # especially if it's critical for the service's operation.
    if @api_key.blank?
      # You might want to raise an error or handle this case appropriately,
      # depending on whether an API key is always required.
      # For example:
      # raise "API key for #{@llm_provider} is missing for user #{@user.id}"
      # For now, we'll allow it to proceed, and the LLM library will likely fail.
      Rails.logger.warn "User #{@user.id} has a blank API key for provider #{@llm_provider}."
    end

    klass = case @llm_provider
    when "openai"
              Langchain::LLM::OpenAI
    when "anthropic"
              Langchain::LLM::Anthropic
    when "gemini"
              Langchain::LLM::GoogleGemini
    else
              raise "Unknown LLM provider: #{@llm_provider}"
    end
    @llm = klass.new(
      api_key: @api_key, # Use the key from user attribute
      default_options: {
        temperature: 0.7,
        chat_model: @user.llm_model # llm_model is still from user preferences
      }
    )
  end

  def generate_suggestions
    messages = format_conversation_history

    response = @llm.chat(messages: messages, response_format: { type: "json_object" })
    parse_suggestions(response.completion)
  rescue => e
    Rails.logger.error "Error generating suggestions: #{e.message}"
    []
  end

  def generate_conversation_summary
    conversation_data = prepare_conversation_data
    prompt = build_summary_prompt
    
    response = call_llm_with_prompt(prompt, conversation_data)
    
    @user.update!(
      conversation_summary: response,
      summary_generated_at: Time.current
    )
    
    response
  end

  private

  def format_conversation_history
    # System message to explain what we want
    system_prompt = I18n.t("suggestions.system_prompt" )
    messages = [ {
      role: "system",
      content: system_prompt
    } ]
    user_message = { context: [], last_message: nil, category: @conversation.initial_sentence.category&.name, user_description: @conversation.user.description, summary: @user.conversation_summary }
    # Add conversation history
    @conversation.messages.order(created_at: :asc).each_with_index do |message, index|
      unless index == @conversation.messages.count - 1
        user_message[:context] << {
          role: message.user? ? "patient" : "visitor",
          content: message.content
        }
      else
        user_message[:last_message] = message
      end
    end
    if user_message.empty?
      user_message << { role: "patient", content: @conversation.initial_sentence.content }
    end

    @last_message = messages << { role: "user", content: user_message.to_json }
  end

  def parse_suggestions(completion)
    begin
      # Ensure completion is not blank, as JSON.parse would error on empty string
      if completion.blank?
        Rails.logger.warn "LLM completion was blank. Cannot parse suggestions."
        return []
      end

      parsed_json = JSON.parse(completion)

      # Check if the expected key "response" exists and is an array
      if parsed_json.is_a?(Hash) && parsed_json.key?("response") && parsed_json["response"].is_a?(Array)
        # Optionally, you could also check if elements in the array are strings
        # e.g., parsed_json["response"].all?(String)
        return parsed_json["response"]
      else
        Rails.logger.error "LLM response JSON does not have the expected structure. Missing 'response' key or it's not an array."
        Rails.logger.error "Received JSON: #{completion}" # Log the problematic JSON string
        return []
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse LLM response as JSON: #{e.message}"
      Rails.logger.error "Problematic string: #{completion}" # Log the problematic string
      return []
    end
  end

  def prepare_conversation_data
    @user.conversations.includes(:messages).order(created_at: :desc).limit(50).map do |conversation|
      {
        id: conversation.id,
        messages: conversation.messages.map do |message|
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
    I18n.t('suggestion_service.summary_prompt')
  end

  def call_llm_with_prompt(prompt, data)
    client = create_llm_client
    
    case @user.llm_provider
    when 'openai'
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
    when 'anthropic'
      response = client.messages(
        model: @user.llm_model || "claude-3-opus-20240229",
        messages: [{ role: "user", content: "#{prompt}\n\nConversations:\n#{data.to_json}" }],
        temperature: 0.7
      )
      response.content.first.text
    when 'gemini'
      response = client.generate_content(
        "#{prompt}\n\nConversations:\n#{data.to_json}",
        temperature: 0.7
      )
      response.text
    else
      raise I18n.t('suggestion_service.errors.unsupported_provider', provider: @user.llm_provider)
    end
  end

  def create_llm_client
    # Ensure @api_key is available (now sourced from user.llm_api_key).
    # A check for blankness was already done in initialize, but an explicit check here
    # before use by specific clients can be useful if the service's lifecycle is complex.
    if @api_key.blank?
      # This situation indicates that the user does not have an API key configured
      # for the selected provider. The specific client libraries might handle
      # nil/blank keys differently (some might error, some might try default env vars).
      # Raising an error here can make debugging easier.
      raise "User #{@user.id} has a blank API key for provider #{@llm_provider}. Cannot create LLM client."
    end

    case @llm_provider # Use @llm_provider instance variable
    when 'openai'
      OpenAI::Client.new(access_token: @api_key)
    when 'anthropic'
      Anthropic::Client.new(access_token: @api_key)
    when 'gemini'
      # Note: The Google::Gemini::Client might expect the key differently.
      # Assuming it also accepts `access_token`. Adjust if necessary.
      Google::Gemini::Client.new(access_token: @api_key)
    else
      # This case should ideally not be reached if User model validation for llm_provider is effective
      # and the case statement in `initialize` is aligned with User::ALLOWED_LLM_PROVIDERS.
      raise I18n.t('suggestion_service.errors.unsupported_provider', provider: @llm_provider)
    end
  end
end
