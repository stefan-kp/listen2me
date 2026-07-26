class SpeechesController < ApplicationController
  def index
    localized_sentences = current_user.sentences
                                      .includes(:category, :language)
                                      .where(language: Language.find_by(code: I18n.locale))

    @frequent_sentences = localized_sentences
                            .where("sentences.usage_count > 0")
                            .order(usage_count: :desc, id: :asc)
                            .limit(10)
                            .to_a

    if @frequent_sentences.any?
      starter_slots = 10 - @frequent_sentences.size
      starter_sentences = localized_sentences
                            .where("COALESCE(sentences.usage_count, 0) = 0")
                            .order(id: :asc)
                            .limit(starter_slots)
                            .to_a
      @featured_sentences = @frequent_sentences + starter_sentences
      @featured_kicker = t(".quick_sentences")
      @featured_title = t(".quick_access")
      @featured_aria_label = t(".quick_access_list")
    else
      @featured_sentences = localized_sentences.order(id: :asc).limit(10).to_a
      @featured_kicker = t(".starter_kicker")
      @featured_title = t(".starter_sentences")
      @featured_aria_label = t(".starter_sentences_list")
    end

    @categories = current_user.categories.order(:id)
    @page_title = @featured_title
    @page_description = @featured_aria_label
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
    @categories = current_user.categories.order(:id)
    @sentences = current_user.sentences
                             .where(
                               category: @category,
                               language: Language.find_by(code: I18n.locale)
                             )
                             .order(usage_count: :desc, id: :asc)
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
    category = current_user.categories.find_by(id: @sentence.category_id)
    @sentence.destroy

    destination = if params[:return_to] == "category" && category.present?
      category_speech_path(id: category.id)
    else
      speeches_path
    end

    redirect_to destination, notice: t(".sentence_deleted")
  end
end
