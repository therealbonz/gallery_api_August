Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :photos, only: [:index, :show, :create, :destroy] do
        collection do
          post :batch, to: 'photos#create_batch'
        end
        member do
          get :image
          post :reactions, to: 'reactions#toggle'
        end
        resources :comments, only: [:index, :create]
      end
      resources :comments, only: [:destroy]
      get '/download/apk', to: 'photos#download_apk'
      post '/signup', to: 'users#create'
      post '/login', to: 'sessions#create'
      get '/me', to: 'sessions#me'
    end
  end
end
