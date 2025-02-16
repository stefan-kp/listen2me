class SuggestionService
  attr_reader :last_message
  def initialize(conversation)
    @conversation = conversation
    @user = conversation.user
    klass = case @conversation.user.llm_provider
    when "openai"
              Langchain::LLM::OpenAI
    when "anthropic"
              Langchain::LLM::Anthropic
    when "gemini"
              Langchain::LLM::GoogleGemini
    else
              raise "Unknown LLM provider: #{@conversation.user.llm_provider}"
    end
    @llm = klass.new(
      api_key: @conversation.user.llm_api_key,
      default_options: {
        temperature: 0.7,
        chat_model: @conversation.user.llm_model
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
    # Parse the completion which should be in array format

    JSON.parse(completion).with_indifferent_access[:response]
  rescue
    begin
      eval(completion)
    rescue
      # Fallback if parsing fails
      completion.split("\n").map { |s| s.gsub(/^\d+\.\s*/, "") }
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
    case @user.llm_provider
    when 'openai'
      OpenAI::Client.new(access_token: @user.llm_api_key)
    when 'anthropic'
      Anthropic::Client.new(access_token: @user.llm_api_key)
    when 'gemini'
      Google::Gemini::Client.new(access_token: @user.llm_api_key)
    end
  end
end
