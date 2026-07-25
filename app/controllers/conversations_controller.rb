class ConversationsController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :suggestions, by: -> { current_user.id }

  def show
    @conversation = current_user.conversations.find(params[:id])
    @messages = @conversation.messages.order(created_at: :asc)
    @suggestions = default_suggestions
  end

  def new
    @conversation = current_user.conversations.build
    @messages = []
    @suggestions = default_suggestions
  end

  def create
    content = params[:content].to_s.strip
    return head :unprocessable_entity if content.length > 240

    sentence = if params[:sentence_id].present?
      current_user.sentences.find(params[:sentence_id])
    elsif content.present?
      category = if params[:category_id].present?
        current_user.categories.find(params[:category_id])
      else
        current_user.categories.first
      end
      current_user.sentences.find_or_create_by!(
        content: content,
        language: Language.find_by!(code: I18n.locale),
        category: category
      ) do |s|
        s.usage_count = 0
      end
    end

    @conversation = current_user.conversations.create!(
      initial_sentence: sentence
    )

    if sentence.present?
      @conversation.messages.create!(
        content: sentence.content,
        role: :speaker
      )
    end

    respond_to do |format|
      format.html { redirect_to conversation_path(id: @conversation.id) }
      format.json { render json: { id: @conversation.id }, status: :created }
    end
  end

  def suggestions
    @conversation = current_user.conversations.find(params[:id])
    @suggestions = if @conversation.messages.exists?
      SuggestionService.new(@conversation).generate_suggestions
    else
      default_suggestions
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("suggestions",
          partial: "messages/suggestions",
          locals: { suggestions: @suggestions }
        )
      end
      format.json { render json: { suggestions: @suggestions } }
    end
  end

  def index
    @conversations = current_user.conversations
                               .includes(:messages, initial_sentence: :category)
                               .order(created_at: :desc)

    @conversation_history_items = @conversations.map do |conversation|
      messages = conversation.messages.sort_by { |message| [ message.created_at, message.id ] }
      first_message = messages.find { |message| message.content.present? }
      last_message = messages.reverse.find { |message| message.content.present? }

      {
        conversation: conversation,
        title: conversation.initial_sentence&.content.presence || first_message&.content.presence,
        last_message: last_message,
        message_count: messages.size,
        last_activity_at: last_message&.created_at || conversation.updated_at || conversation.created_at,
        category: conversation.initial_sentence&.category
      }
    end.sort_by { |item| item.fetch(:last_activity_at) }.reverse
  end

  private

  def default_suggestions
    locale = I18n.locale.to_s.start_with?("de") ? "de" : "en"
    SuggestionService::FALLBACK_SUGGESTIONS.fetch(locale).map(&:dup)
  end
end
