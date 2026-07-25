class SettingsController < ApplicationController
  rate_limit to: 3, within: 1.hour, only: :generate_summary, by: -> { current_user.id }

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
    if service.generate_conversation_summary.present?
      redirect_to settings_path, notice: t(".success")
    else
      redirect_to settings_path, alert: t(".error")
    end
  rescue StandardError => e
    Rails.logger.warn "Conversation summary generation failed (#{e.class})"
    redirect_to settings_path, alert: t(".error")
  end

  private

  def settings_params
    params.require(:user).permit(:description, :suggestion_model_profile)
  end
end
