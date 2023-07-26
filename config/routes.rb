Rails.application.routes.draw do
  get '/current_user', to: 'current_user#index'
  resources :stocks do
    collection do
      post 'save_favourite/:id', to: 'stocks#save_favourite'
      delete 'delete_favourite/:id', to: 'stocks#delete_favourite'
      get 'recommendation', to: 'stocks#recommendation'
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  devise_for :users, path: '', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    registration: 'signup'
  },
  controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
end
