class SettingsController < ApplicationController
  SETTINGS_SECTIONS = %w[profile voice-device system account].freeze

  rate_limit to: 3, within: 1.hour, only: :generate_summary, by: -> { current_user.id }
  before_action :set_settings_context, only: %i[show update]

  def show
  end

  def update
    @active_settings_section = settings_section

    if current_user.update(settings_params)
      redirect_to settings_location(@active_settings_section), notice: t(".updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def generate_summary
    conversation = current_user.conversations
                               .joins(:messages)
                               .order("conversations.created_at DESC")
                               .first
    unless conversation
      redirect_to settings_location("system"), alert: t(".no_conversations")
      return
    end

    service = SuggestionService.new(conversation)
    if service.generate_conversation_summary.present?
      redirect_to settings_location("system"), notice: t(".success")
    else
      redirect_to settings_location("system"), alert: t(".error")
    end
  rescue StandardError => e
    Rails.logger.warn "Conversation summary generation failed (#{e.class})"
    redirect_to settings_location("system"), alert: t(".error")
  end

  private

  def set_settings_context
    @active_settings_section = settings_section
    @speech_provider_status = Voice::SpeechOutput.provider_status(user: current_user)
    @summary_available = current_user.conversations.joins(:messages).exists?
  end

  def settings_params
    params.require(:user).permit(:description, :suggestion_model_profile, :speech_provider)
  end

  def settings_section
    requested_section = params[:settings_section].to_s
    SETTINGS_SECTIONS.include?(requested_section) ? requested_section : "profile"
  end

  def settings_location(section)
    settings_path(settings_section: section)
  end
end
