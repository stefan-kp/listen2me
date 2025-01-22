class SpeechesController < ApplicationController
  def index
    @frequent_sentences = Sentence.includes(:category, :language)
                                .where(language: Language.find_by(code: I18n.locale))
                                .order(usage_count: :desc)
                                .limit(10)
  end

  def create
    text = params[:content].to_s.strip
    return head :bad_request if text.blank?

    # Finde existierenden Satz oder erstelle einen neuen
    sentence = Sentence.find_or_create_by!(
      content: text,
      language: Language.find_by!(code: I18n.locale),
      user: current_user,
      category_id: params[:category_id] || Category.find_by!(name: 'General').id
    ) do |s|
      s.usage_count = 0
    end

    sentence.increment!(:usage_count)
    sentence.category&.increment!(:usage_count)
    
    respond_to do |format|
      format.json do
        render json: {
          text: sentence.content,
          voice_id: sentence.user.voice_identifier,
          model_id: "eleven_multilingual_v2",
          api_key: Rails.application.credentials.elevenlabs[:secret]
        }
      end
      format.html { redirect_to speeches_path }
    end
  end

  def category
    @category = Category.find(params[:id])
    @sentences = @category.sentences
                         .where(language: Language.find_by(code: 'de'))
                         .order(usage_count: :desc)
  end

  def speak
    @sentence = Sentence.find(params[:id])
    @sentence.increment!(:usage_count)
    @sentence.category&.increment!(:usage_count)
    
    render json: {
      text: @sentence.content,
      voice_id: @sentence.user.voice_identifier,
      model_id: "eleven_multilingual_v2",
      api_key: Rails.application.credentials.elevenlabs[:secret]
    }
  end

  def destroy
    @sentence = Sentence.find(params[:id])
    @sentence.destroy

    redirect_to speeches_path, notice: t('.sentence_deleted')
  end
end 