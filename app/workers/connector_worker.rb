class ConnectorWorker
  include Sidekiq::Worker
  def perform
      Synergy1c7Connector::Connection.new.parse_with_ftp_copy(Rails.root.to_s)
  end
end


