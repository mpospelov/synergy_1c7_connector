#encoding: UTF-8
class Admin::OneC7ConnectorsController < Admin::BaseController
    def create
        Synergy1c7Connector::Connection.parse_xml
        redirect_to new_admin_one_c7_connector_path, :notice => t(:successful_1c_import)
    end

    def discharge
        @order = Order.find_by_number(params[:id])
        Synergy1c7Connector::Connection.discharge(@order)
        redirect_to edit_admin_order_path(@order), :notice => t(:succesful_1c_discharge)
    end
end
