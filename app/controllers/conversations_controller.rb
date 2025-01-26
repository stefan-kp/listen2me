class ConversationsController < ApplicationController
  def show
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.messages.order(created_at: :asc)
    @suggestions = SuggestionService.new(@conversation).generate_suggestions
  end

  def create
    # Erst den Satz erstellen, wenn content übergeben wurde
    sentence = if params[:sentence_id].present?
      current_user.sentences.find(params[:sentence_id])
    else
      category = current_user.categories.find(params[:category_id])
      Sentence.find_or_create_by!(
        content: params[:content],
        language: Language.find_by!(code: I18n.locale),
        user: current_user,
        category: category
      ) do |s|
        s.usage_count = 0
      end
    end

    @conversation = Conversation.create!(
      user: current_user,
      initial_sentence: sentence
    )

    # Erste Nachricht erstellen mit dem initial_sentence
    @conversation.messages.create!(
      content: sentence.content,
      role: :user
    )

    redirect_to @conversation
  end

  def suggestions
    @conversation = current_user.conversations.find(params[:id])
    @suggestions = SuggestionService.new(@conversation).generate_suggestions

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("suggestions",
          partial: "messages/suggestions",
          locals: { suggestions: @suggestions }
        )
      end
    end
  end

  def index
    @conversations = current_user.conversations
                               .includes(:messages, initial_sentence: :category)
                               .order(created_at: :desc)
  end
end
