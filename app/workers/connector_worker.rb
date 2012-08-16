class ConnectorWorker
  include Sidekiq::Worker
  def perform
      Synergy1c7Connector::Connection.new.parse_xml("#{Rails.root}/../../shared")
  end
end


