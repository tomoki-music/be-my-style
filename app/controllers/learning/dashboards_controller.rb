class Learning::DashboardsController < Learning::BaseController
  def show
    @school_groups = current_customer.learning_school_groups.ordered
    @selected_school_group = current_customer.learning_school_groups.find_by(id: params[:learning_school_group_id])
    @dashboard = Learning::DashboardBuilder.new(current_customer, school_group: @selected_school_group).build
  end
end
