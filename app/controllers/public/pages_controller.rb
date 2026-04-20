class Public::PagesController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:legal, :terms, :privacy]
  
  def legal
  end

  def terms 
  end

  def privacy 
  end
  
end
