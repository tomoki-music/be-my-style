Rails.application.routes.draw do

  root to: 'public/homes#top'

  namespace :admin do
    get 'homes/top'

    # イベント機能
   resources :events do
    resources :songs, only: [:create, :destroy]
    delete "delete" => "events#delete"
   end
  end
  
  namespace :public do
    get 'homes/top'
    get 'homes/about'

    # アーティスト関連
    resources :customers, only: [:index,:show,:edit,:update] do
      member do
        get "mypage/edit_password", :to =>"customers#edit_password"
        put "mypage/password", :to => "customers#update_password"
      end
      resource :relationships, only: [:create, :destroy]
      get 'followings' => 'relationships#followings', as: 'followings'
      get 'followers' => 'relationships#followers', as: 'followers'
    end

    # 活動報告機能
    resources :activities do
      resource :favorites, only: [:create, :destroy]
      resources :comments, only: [:create, :destroy]
    end

    # イベント機能
    resources :events do
      collection do
        get "copy" => "events#copy"
      end
      post "join" => "events#join"
      delete "delete" => "events#delete"
      resources :songs, only: [:create, :destroy]
      resources :requests, only: [:create, :destroy]
    end

    # 通知機能
    resources :notifications, only: :index

    # マッチング〜チャット機能
    resources :matchings, only: [:index]
    resources :chat_rooms, only: [:create, :show] do
      get "community_show/:id" => "chat_rooms#community_show", on: :collection, as: :community_show
      post "community_create" => "chat_rooms#community_create", on: :collection
    end
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
  confirmations: 'public/confirmations',
  tracks: 'public/tracks',
}

devise_scope :customer do
  get "verify", :to => "public/registrations#verify"
end

# 管理者用
devise_for :admin, skip: [:registrations, :passwords, :confirmations], controllers: {
  sessions: "admin/sessions"
}

devise_scope :admin do
  patch "approval", :to => "admin/customers#approval"
  delete "purge", :to => "admin/customers#purge"
end
  
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
