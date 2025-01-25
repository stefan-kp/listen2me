class SuggestionService
  attr_reader :last_message
  def initialize(conversation)
    @conversation = conversation
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

  private

  def format_conversation_history
    # System message to explain what we want
    messages = [{
      role: "system",
      content: I18n.t('suggestions.system_prompt')
    }]
    user_message = {context: [], last_message: nil, category: @conversation.initial_sentence.category&.name, user_description: @conversation.user.description }
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
      completion.split("\n").map { |s| s.gsub(/^\d+\.\s*/, '') }
    end
  end
end 