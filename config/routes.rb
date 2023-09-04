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

    resources :activities do
      resource :favorites, only: [:create, :destroy]
   end

    # 通知機能
    resources :notifications, only: :index

    # マッチング〜チャット機能
    resources :matchings, only: [:index]
    resources :chat_rooms, only: [:create, :show] do
      get "community_show/:id" => "chat_rooms#community_show", on: :collection, as: :community_show
      post "community_create" => "chat_rooms#community_create", on: :collection
    end
    # get "chat_rooms/community_show/:id" => "chat_rooms#community_show", as: :community_show
    resources :chat_messages, only: [:create] do
      post "community_create" => "chat_messages#community_create", on: :collection
    end

    # コミュニティ機能
    resources :communities do
      delete "leave" => "communities#leave"
      get "new/mail" => "communities#new_mail"
      get "send/mail" => "communities#send_mail"
      resource :permits, only: [:create, :destroy]
      resource :community_customers, only: [:create, :destroy]
    end
    get "communities/:id/permits" => "communities#permits", as: :permits
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
