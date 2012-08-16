class ConnectorWorker
  include Sidekiq::Worker
  def perform
      Synergy1c7Connector::Connection.new.parse_xml("#{Rail.root}/../../shared")
  end
end


