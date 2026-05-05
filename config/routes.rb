Rails.application.routes.draw do

  namespace :public do
    get 'lp/index'
    get 'stripe/success', to: 'stripe#success', as: :success_stripe
  end
  root to: 'public/homes#top'

  # オンボーディング
  get "onboarding/music", to: "onboardings#music", as: :onboarding_music
  get "onboarding/business", to: "onboardings#business", as: :onboarding_business
  patch "onboarding/complete", to: "onboardings#complete"

  get "onboarding/step1", to: "onboardings#step1", as: :onboarding_step1
  get "onboarding/step2", to: "onboardings#step2", as: :onboarding_step2
  get "onboarding/step3", to: "onboardings#step3", as: :onboarding_step3

  namespace :admin do
    get 'homes/top'
    get 'analytics', to: 'analytics#show'

    # アーティスト編集機能
    resources :customers, only: [:edit, :update]

    resources :communities
    resources :activities
    resources :activity_comments
    resources :event_comments

    # イベント機能
    resources :events do
      resources :songs, only: [:create, :destroy]
      delete "delete" => "events#delete"
    end
  end
  
  namespace :public do
    get 'homes/top'
    get 'homes/about'

    # ランディングページ
    get 'lp', to: 'lp#index'
    get 'lp/singing', to: 'lp#singing', as: :singing_lp
    get 'singing_performance_diagnosis', to: 'singing_performance_diagnoses#show'

    # サブスク
    post '/webhooks/stripe', to: 'webhooks#stripe'
    post 'checkout/:plan', to: 'stripe#create_checkout', as: :checkout
    post '/portal', to: 'stripe#portal'

    # 特定商取引法、プライバシーポリシー、利用規約
    get 'legal', to: 'pages#legal'
    get 'terms', to: 'pages#terms'
    get 'privacy', to: 'pages#privacy'

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
      resources :reactions, only: [:create], controller: "activity_reactions"
    end

    # イベント機能
    resources :events do
      member do
        get "copy" => "events#copy"
      end
      post "join" => "events#join"
      delete "delete" => "events#delete"
      get "join_confirm" => "events#join_confirm"
      resources :songs, only: [:create, :destroy, :show]
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

    %i[singing business learning].each do |domain_name|
      get  "#{domain_name}/sign_in",      to: "#{domain_name}/sessions#new",         as: :"new_#{domain_name}_customer_session"
      post "#{domain_name}/sign_in",      to: "#{domain_name}/sessions#create",      as: :"#{domain_name}_customer_session"
      get  "#{domain_name}/sign_up",      to: "#{domain_name}/registrations#new",    as: :"new_#{domain_name}_customer_registration"
      post "#{domain_name}/sign_up",      to: "#{domain_name}/registrations#create", as: :"#{domain_name}_customer_registration"
      get  "#{domain_name}/password/new", to: "#{domain_name}/passwords#new",        as: :"new_#{domain_name}_customer_password"
      post "#{domain_name}/password",     to: "#{domain_name}/passwords#create",     as: :"#{domain_name}_customer_password"
    end
  end

  # 管理者用
  devise_for :admin, skip: [:registrations, :passwords, :confirmations], controllers: {
    sessions: "admin/sessions"
  }

  devise_scope :admin do
    patch "approval", :to => "admin/customers#approval"
    delete "purge", :to => "admin/customers#purge"
  end

  # =====================
  # BUSINESS（新規）
  # =====================
  namespace :business do
    root to: 'homes#top'
    get  "join", to: "joins#show", as: :join
    post "join", to: "joins#create"

    post 'checkout/:plan', to: 'stripe#create_checkout', as: :checkout
    post '/portal', to: 'stripe#portal'
    get 'stripe/success', to: 'stripe#success', as: :success_stripe

    # ユーザー
    resources :customers, only: [:show, :edit, :update] do
      resource :relationships, only: [:create, :destroy]
    end

    # 投稿
    resources :posts do
      resources :messages, only: [:create, :destroy]
      resource :like, only: [:create, :destroy]
    end

    get "timeline", to: "posts#timeline"

    resources :notifications, only: [:index]

    resources :projects do
      member do
        post :join
        delete :leave
      end

      resources :project_chats, only: [:create, :destroy]
    end

    resources :communities do
      delete "leave" => "communities#leave"

      get "new/mail" => "communities#new_mail"
      get "send/mail" => "communities#send_mail"
      resource :permit, only: [:create, :destroy]
      resource :community_customers, only: [:create, :destroy]
      resources :community_posts
    end

    get "communities/:id/permits" => "communities#permits", as: :permits
  end

  namespace :singing do
    root to: "homes#top"
    resources :diagnoses, only: [:index, :new, :create, :show]
    resources :rankings, only: [:index]
    resources :users, only: [:show, :edit, :update] do
      resource :profile_reaction, only: [:create]
    end
    get  "join", to: "joins#show",   as: :join
    post "join", to: "joins#create"
  end

  namespace :learning do
    root to: "dashboards#show"
    get  "join", to: "joins#show", as: :join
    post "join", to: "joins#create"

    resource :dashboard, only: :show, controller: :dashboards
    get "portal/:token", to: "student_portals#show", as: :student_portal
    resources :school_groups
    resources :students do
      member do
        post :send_portal_mail
      end
      resources :student_trainings, only: [:index, :create] do
        collection do
          patch :reorder
        end
      end
      resources :progress_logs, only: [:new, :create]
    end
    resources :training_masters, except: :show
    resources :student_trainings, only: [:edit, :update, :destroy] do
      member do
        patch :mark
      end
    end
    resources :progress_logs, only: [:index, :edit, :update, :destroy]
    resources :bands
    resources :band_trainings, except: :show do
      member do
        patch :mark
      end
    end
  end

  # For details on the DSL available within this file, see
  # https://guides.rubyonrails.org/routing.html
end
