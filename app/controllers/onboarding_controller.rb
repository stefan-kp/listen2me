class OnboardingController < ApplicationController
  def show
  end

  def update
    attributes = params[:skip].present? ? {} : onboarding_params
    attributes[:onboarding_completed_at] = Time.current

    if current_user.update(attributes)
      session[:locale] = current_user.preferred_locale
      redirect_to speeches_path(locale: current_user.preferred_locale),
        notice: t(".completed")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def onboarding_params
    params.require(:user).permit(
      :preferred_locale,
      :preferred_speech_mode,
      :description
    )
  end
end
