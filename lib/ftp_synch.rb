#encoding: UTF-8
require 'net/ftp'
module FtpSynch
  class Get
    def dowload_dir(path)
      ftp = Net::FTP.open('172.30.65.35', 'ru_ftpuser', 'FTP!pwd00')
      ftp.binary = true
      ftp.passive = true
      ftp.chdir('webdata')
      puts 'Start dowloading'
      download_files(ftp.getdir, ftp, path)
      puts 'End dowloading'
      ftp.close
    end
    def upload_from_xml(xml_string)
      ftp = Net::FTP.open('172.30.65.35', 'ru_ftpuser', 'FTP!pwd00')
      ftp.chdir('webdata')
      xml_string << "</КоммерческаяИнформация>"
      File.open("from.xml", 'w') { |f| f.write(xml_string) }
      puts 'Start uploading'
      ftp.put('from.xml', File.basename('from.xml'))
      puts 'Finish!!!'
    end
    private
    def download_files(dir, ftp, home_dir)
        ftp.chdir(dir)
        dir_files = ftp.list
        dir_files.each do |name|
            if name.include?("<DIR>")
                Dir.mkdir(home_dir + "/" + ftp.getdir.to_s[1..-1]) if !File.directory?(home_dir + "/" + ftp.getdir.to_s[1..-1])
                download_files(name.split.last, ftp, home_dir)
            else
                Dir.mkdir(home_dir + "/" + ftp.getdir.to_s[1..-1]) if !File.directory?(home_dir + "/" + ftp.getdir.to_s[1..-1])
                Dir.chdir(home_dir + "/" + ftp.getdir.to_s[1..-1])
                puts "\t DOWNLOAD : " + ftp.getdir.to_s + name.split.last.to_s
                ftp.getbinaryfile(name.split.last)
            end
        end
        ftp.chdir('../')
        Dir.chdir('../')
    end
  end
end

