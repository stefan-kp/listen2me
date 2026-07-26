class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_locale
  before_action :require_completed_onboarding

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  private

  def set_locale
    I18n.locale = if params[:locale]
      session[:locale] = params[:locale]
    else
      session[:locale] || current_user&.preferred_locale || I18n.default_locale
    end
  end

  def require_completed_onboarding
    return unless user_signed_in?
    return if current_user.onboarding_completed?
    return if devise_controller? || controller_name == "onboarding"
    return unless request.get? && request.format.html?

    redirect_to onboarding_path(locale: current_user.preferred_locale)
  end

  def after_sign_in_path_for(resource)
    return onboarding_path(locale: resource.preferred_locale) unless resource.onboarding_completed?

    super
  end

  def after_sign_up_path_for(resource)
    onboarding_path(locale: resource.preferred_locale)
  end

  def default_url_options
    { locale: I18n.locale }
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper Heroicon::Engine.helpers
end
