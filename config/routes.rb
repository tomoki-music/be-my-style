Rails.application.routes.draw do

  namespace :admin do
    get 'homes/top'
    root to: 'homes#top'
  end
  namespace :public do
    get 'homes/top'
    root to: 'homes#top'
    resources :customers, only: [:index,:show,:edit,:update]
  end

# 顧客用
devise_for :customers, controllers: {
  registrations: "public/registrations",
  sessions: 'public/sessions',
  passwords: 'public/passwords',
}

# 管理者用
devise_for :admin, skip: [:registrations, :passwords], controllers: {
  sessions: "admin/sessions"
}
  
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
