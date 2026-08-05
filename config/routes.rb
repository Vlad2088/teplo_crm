Rails.application.routes.draw do
  devise_for :users
  resources :clients
  resources :products
  resources :services
  resources :orders do
    resources :payments
    resources :documents
    resources :order_items
  end
  resources :stock_movements

  # Reveal health status on /up
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "orders#index"
end
