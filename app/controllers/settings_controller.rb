class SettingsController < ApplicationController
  def show
  end

  def update
    if current_user.update(settings_params)
      redirect_to root_path, notice: t(".updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def generate_summary
    service = SuggestionService.new(current_user.conversations.first)
    service.generate_conversation_summary
    redirect_to settings_path, notice: t('.success')
  rescue => e
    Rails.logger.error "Error generating summary: #{e.message}"
    redirect_to settings_path, alert: t('.error', message: e.message)
  end

  private

  def settings_params
    params.require(:user).permit(
      :elevenlabs_api_key,
      :elevenlabs_voice_id,
      :llm_api_key,
      :llm_provider,
      :llm_model,
      :description
    )
  end
end
