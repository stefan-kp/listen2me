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
    service = SuggestionService.new(current_user.conversations.last)
    service.generate_conversation_summary
    redirect_to settings_path, notice: t(".success")
  rescue StandardError => e
    Rails.logger.warn "Conversation summary generation failed (#{e.class})"
    redirect_to settings_path, alert: t(".error")
  end

  private

  def settings_params
    permitted = params.require(:user).permit(
      :elevenlabs_api_key,
      :elevenlabs_voice_id,
      :llm_api_key,
      :llm_provider,
      :llm_model,
      :description
    )

    %w[elevenlabs_api_key llm_api_key].each do |credential|
      permitted.delete(credential) if permitted[credential].blank?
    end

    permitted
  end
end
