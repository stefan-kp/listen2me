class SpeechesController < ApplicationController
  def index
    @frequent_sentences = current_user.sentences
                                      .includes(:category, :language)
                                      .where(language: Language.find_by(code: I18n.locale))
                                      .order(usage_count: :desc)
                                      .limit(10)
    @categories = current_user.categories
    # Fügen Sie einen Titel für Screen Reader hinzu
    @page_title = t(".frequent_sentences")
    @page_description = t(".frequent_sentences_description")
    @category = current_user.categories.find_by(name: "Basic Needs")
  end

  def create
    text = params[:content].to_s.strip
    return head :unprocessable_entity if text.blank? || text.length > 240

    category = if params[:category_id].present?
      current_user.categories.find(params[:category_id])
    else
      current_user.categories.first
    end

    @sentence = current_user.sentences.find_or_create_by!(
      content: text,
      language: Language.find_by!(code: I18n.locale),
      category: category
    ) do |s|
      s.usage_count = 0
    end

    @sentence.increment!(:usage_count)
    @sentence.category&.increment!(:usage_count)

    respond_to do |format|
      format.html { redirect_to speeches_path, notice: t(".sentence_saved", default: "Satz wurde gesprochen und gespeichert.") }
      format.json { render json: { id: @sentence.id, text: @sentence.content }, status: :created }
    end
  end

  def category
    @category = current_user.categories.find(params[:id])
    @categories = current_user.categories
    @sentences = current_user.sentences
                             .where(
                               category: @category,
                               language: Language.find_by(code: I18n.locale)
                             )
                             .order(usage_count: :desc)
  end

  def speak
    @sentence = current_user.sentences.find(params[:id])
    @sentence.increment!(:usage_count)
    current_user.categories.find_by(id: @sentence.category_id)&.increment!(:usage_count)

    render json: {
      text: @sentence.content,
      aria_label: t(".speaking_sentence", text: @sentence.content)
    }
  end

  def destroy
    @sentence = current_user.sentences.find(params[:id])
    @sentence.destroy

    redirect_to speeches_path, notice: t(".sentence_deleted")
  end
end
