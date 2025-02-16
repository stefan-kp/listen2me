class SpeechesController < ApplicationController
  def index
    @frequent_sentences = Sentence.includes(:category, :language)
                                .where(language: Language.find_by(code: I18n.locale))
                                .order(usage_count: :desc)
                                .limit(10)
    @categories = Category.where(user: current_user)
    # Fügen Sie einen Titel für Screen Reader hinzu
    @page_title = t(".frequent_sentences")
    @page_description = t(".frequent_sentences_description")
    @category = Category.find_by(name: "Basic Needs")
  end

  def create
    text = params[:content].to_s.strip
    return head :bad_request if text.blank?

    @sentence = Sentence.find_or_create_by!(
      content: text,
      language: Language.find_by!(code: I18n.locale),
      user: current_user,
      category_id: params[:category_id] || Category.find_by!(name: "General").id
    ) do |s|
      s.usage_count = 0
    end

    @sentence.increment!(:usage_count)
    @sentence.category&.increment!(:usage_count)

    @conversation = Conversation.create!(
      initial_sentence: @sentence,
      user: current_user
    )

    @conversation.messages.create!(
      content: text,
      role: 'user'
    )

    # Einfache Weiterleitung für neue Konversationen
    redirect_to conversation_path(@conversation)
  end

  def category
    @category = Category.find(params[:id])
    @sentences = @category.sentences
                         .where(language: Language.find_by(code: I18n.locale))
                         .order(usage_count: :desc)
  end

  def speak
    @sentence = Sentence.find(params[:id])
    @sentence.increment!(:usage_count)
    @sentence.category&.increment!(:usage_count)

    render json: {
      text: @sentence.content,
      voice_id: @sentence.user.elevenlabs_voice_id,
      model_id: @sentence.user.llm_model,
      api_key: @sentence.user.elevenlabs_api_key,
      aria_label: t(".speaking_sentence", text: @sentence.content)
    }
  end

  def destroy
    @sentence = Sentence.find(params[:id])
    @sentence.destroy

    redirect_to speeches_path, notice: t(".sentence_deleted")
  end
end
