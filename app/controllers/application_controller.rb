class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_locale

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name, :elevenlabs_api_key, :elevenlabs_voice_id, :llm_model, :llm_provider, :llm_api_key ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name, :elevenlabs_api_key, :elevenlabs_voice_id, :llm_model, :llm_provider, :llm_api_key ])
  end

  private

  def set_locale
    I18n.locale = if params[:locale]
      session[:locale] = params[:locale]
    else
      session[:locale] || I18n.default_locale
    end
  end

  def default_url_options
    { locale: I18n.locale }
  end


  def current_elevenlabs_api_key
    user_signed_in? ? current_user.elevenlabs_api_key : nil
  end

  helper_method :current_elevenlabs_api_key

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper Heroicon::Engine.helpers
end
