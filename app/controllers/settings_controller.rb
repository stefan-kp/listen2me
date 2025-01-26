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
