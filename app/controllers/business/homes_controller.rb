class Business::HomesController < ApplicationController
  def top
    @posts = Post.order(created_at: :desc).limit(4)
    # @projects = Project.order(created_at: :desc).limit(5)
    # @communities = Community.order(created_at: :desc).limit(5)

    @projects = []
    @communities = []
    @customers = Customer
                  .joins(:domains)
                  .where(domains: { name: "business" })
                  .order(created_at: :desc)
                  .limit(4)
    end
end
