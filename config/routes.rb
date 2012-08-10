Rails.application.routes.draw do
  namespace :admin do
    resource :one_c7_connector, :only => [:new, :create]
  end
  match 'admin/1c_discharge_orders/:id' => 'admin/one_c7_connectors#discharge', :as => :discharge
end
