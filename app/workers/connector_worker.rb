class ConnectorWorker
  include Sidekiq::Worker
  def perform
      FtpSynch::Get.new.dowload_dir(Rails.root.to_s)
      Synergy1c7Connector::Connection.new.parse_xml
  end
end


