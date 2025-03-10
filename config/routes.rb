Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  scope "(:locale)", locale: /#{I18n.available_locales.join('|')}/ do
    root "speeches#index"

    resources :speeches do
      member do
        get :speak
        get :category
      end
    end

    resources :conversations do
      member do
        get :suggestions
      end
      resources :messages, only: [ :create ]
    end

    resource :settings, only: %i[show update] do
      post :generate_summary, on: :collection
    end

    resources :categories, except: [:show] do
      delete :destroy, on: :member
    end
  end
end
