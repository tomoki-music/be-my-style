Rails.application.routes.draw do

  root to: 'public/homes#top'

  namespace :admin do
    get 'homes/top'
  end
  namespace :public do
    get 'homes/top'
    resources :customers, only: [:index,:show,:edit,:update] do
      resource :relationships, only: [:create, :destroy]
      get 'followings' => 'relationships#followings', as: 'followings'
      get 'followers' => 'relationships#followers', as: 'followers'
    end
    resources :notifications, only: :index

    # マッチング〜チャット機能
    resources :matchings, only: [:index]
    resources :chat_rooms, only: [:create, :show]
    resources :chat_messages, only: [:create]
  end

# 顧客(アーティスト)用
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
