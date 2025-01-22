class ApplicationController < ActionController::Base
  before_action :set_locale
  
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

  def current_user
    @current_user ||= User.first
  end

  helper_method :current_user

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper Heroicon::Engine.helpers
end
