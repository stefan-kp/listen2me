class SpeechOutputsController < ApplicationController
  include ActionController::Live

  MAX_TEXT_LENGTH = 240
  CONTENT_TYPE = "application/vnd.listen2me.pcm-stream"
  END_FRAME = [ 0 ].pack("L<").freeze

  rate_limit to: 90, within: 1.minute, only: :create, by: -> { current_user.id }

  def create
    text = params[:text].to_s.strip
    return head :unprocessable_entity if text.blank? || text.length > MAX_TEXT_LENGTH

    provider = params[:provider].presence || current_user.speech_provider
    return head :unprocessable_entity unless User::SPEECH_PROVIDERS.include?(provider)
    return head :no_content if provider == "browser"

    response.headers["Content-Type"] = CONTENT_TYPE
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Listen2Me-Sample-Rate"] = Voice::SpeechOutput::SAMPLE_RATE.to_s

    Voice::SpeechOutput.new(
      user: current_user,
      provider:,
      locale: I18n.locale
    ).stream(text:, on_provider: ->(name) { response.headers["X-Listen2Me-Provider"] = name }) do |chunk|
      response.stream.write([ chunk.bytesize ].pack("L<"))
      response.stream.write(chunk)
    end
    response.stream.write(END_FRAME)
  rescue Voice::UnavailableError => error
    Rails.logger.warn "Speech output unavailable (#{error.class})"
    response.status = :service_unavailable unless response.committed?
  ensure
    response.stream.close
  end
end
