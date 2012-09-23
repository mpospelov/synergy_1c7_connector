#encoding: UTF-8
class Admin::OneC7ConnectorsController < Admin::BaseController
    def show

    end
    def create
        ConnectorWorker.perform_async
        redirect_to admin_one_c7_connector_path, :notice => t(:successful_1c_import)
    end

    def discharge
        @one_c_connector = Synergy1c7Connector::Connection.new
        @order = Order.find_by_number(params[:id])
        @one_c_connector.discharge(@order)
        redirect_to edit_admin_order_path(@order), :notice => t(:succesful_1c_discharge)
    end
end
