Rails.application.routes.draw do
  root 'statements#index'

  resources :statements, only: [:index, :create, :show, :destroy] do 
    member do
      put :update_data_points
    end
  end
end
