class MessagesController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    @message = @conversation.messages.create!(
      content: params[:content],
      role: params[:role] || 'user'
    )
    # Suggestions nach dem Erstellen der Message generieren
    @suggestions = SuggestionService.new(@conversation).generate_suggestions

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("messages", partial: "messages/message", locals: { message: @message }),
          turbo_stream.update("suggestions", partial: "messages/suggestions", locals: { suggestions: @suggestions })
        ]
      end
      format.html { redirect_to @conversation }
      format.json { render json: { success: true } }
    end
  end
end
