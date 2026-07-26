class SpeechModesController < ApplicationController
  def update
    mode = params.dig(:speech_mode, :mode).to_s
    return head :unprocessable_entity unless User::PREFERRED_SPEECH_MODES.include?(mode)

    current_user.update!(preferred_speech_mode: mode)
    head :no_content
  end
end
