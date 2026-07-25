class MessagesController < ApplicationController
  rate_limit to: 120, within: 1.minute, only: :create, by: -> { current_user.id }

  def create
    @conversation = current_user.conversations.find(params[:conversation_id])
    content = params[:content].to_s.strip
    return head :unprocessable_entity if content.blank? || content.length > 240

    role = params[:role].to_s
    return head :unprocessable_entity unless Message.roles.key?(role)

    @message = @conversation.messages.create!(
      content: content,
      role: role
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "messages",
          partial: "messages/message",
          locals: { message: @message }
        )
      end
      format.html { redirect_to conversation_path(id: @conversation.id) }
      format.json do
        render json: {
          success: true,
          message: {
            id: @message.id,
            content: @message.content,
            role: @message.role
          }
        }, status: :created
      end
    end
  end
end
