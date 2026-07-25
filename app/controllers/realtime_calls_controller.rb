class RealtimeCallsController < ApplicationController
  MAX_SDP_BYTES = 64.kilobytes

  rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_user.id }

  def create
    conversation = current_user.conversations.find(params[:conversation_id])
    return head :unprocessable_entity unless realtime_configured?
    return head :unsupported_media_type unless request.media_type == "application/sdp"

    sdp = request.raw_post
    return head :unprocessable_entity if sdp.blank? || sdp.bytesize > MAX_SDP_BYTES

    result = OpenAI::RealtimeCall.call(
      user: current_user,
      conversation: conversation,
      sdp: sdp,
      locale: I18n.locale
    )

    if result.success?
      render plain: result.body, status: :created, content_type: "application/sdp"
    else
      Rails.logger.warn "Realtime session setup failed (upstream status #{result.status})"
      head :bad_gateway
    end
  rescue OpenAI::RealtimeCall::ConnectionError => error
    Rails.logger.warn "Realtime session setup failed (#{error.class})"
    head :service_unavailable
  end

  private

  def realtime_configured?
    OpenAI::RealtimeCall.configured?
  end
end
