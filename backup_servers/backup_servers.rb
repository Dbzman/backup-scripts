#!/usr/bin/ruby

require 'rubygems'
require 'net/sftp'
require 'json'
require 'openssl'
require 'prowly'
require 'logger'

begin

# ---- preparing logs ----
logger = Logger.new('logfile.log')
logger.level = Logger::INFO

# ---- configuration ----
config_file = File.read("#{File.dirname(__FILE__)}/config.json")

config = JSON.parse(config_file)

api_key = "38958a23d7815509541df3837f58897a543444a1"


# ---- preparation ----
logger.info('prepare') { "preparing folders" }
current_time = Time.new
current_time = current_time.strftime "%Y-%m-%d"
BACKUP_PATH = "#{config['backup_path']}/#{current_time}"
DELETE_AFTER_DOWNLOAD = config['delete_after_download']
logger.info('expectedBackupPath') { "BACKUP_PATH: #{BACKUP_PATH}" }
logger.info('deletionOfRemoteFiles') { DELETE_AFTER_DOWNLOAD ? "removing files afterwards" : "files won't be removed" }

errors_to_send = []

# create a new folder with current_time
if !File.exists?(BACKUP_PATH)
	Dir.mkdir(BACKUP_PATH)
	logger.info('usedFolder') { "folder #{current_time} created" }
else 
	logger.info('usedFolder') { "folder #{current_time} already exists, skipping..." }
end


# ---- remote work ---- 
config['remotes'].each do |remote|	
	Net::SFTP.start(remote['url'], remote['username'], :password => remote['password']) do |sftp|
		logger.info('downloadStarting') { "downloading from host #{remote['name']}" }
		remote['dirs'].each do |remote_dir|

			downloaded_files = 0
			sftp.dir.foreach(remote_dir) do |entry|
				if !File.exists?("#{BACKUP_PATH}/#{remote['name']}")
					Dir.mkdir("#{BACKUP_PATH}/#{remote['name']}")
					logger.info('localFolderCreated') { "folder #{remote['name']} created" }
				end

				if (!entry.name.start_with?(".") and entry.name.include?("."))
					logger.info('downloadingFile') { "downloading #{entry.name}" }
					downloaded_files += 1
					sftp.download!("#{remote_dir}/#{entry.name}", "#{BACKUP_PATH}/#{remote['name']}/#{entry.name}")
					if (DELETE_AFTER_DOWNLOAD)
						sftp.remove!("#{remote_dir}/#{entry.name}")
						logger.info('remoteFileRemoved') { "removed #{entry.name}" }
					end
				end

				
			end
			if (downloaded_files == 0)
				logger.warn('folderEmpty') { "folder '#{remote_dir}' of host '#{remote['name']}' is empty!" }
				errors_to_send << "- folder '#{remote_dir}' of host '#{remote['name']}' is empty!"
			end
		end
	end
end

logger.info('exit') { "finished downloading backups" }

if errors_to_send.size != 0
	Prowly.notify do |n|
		n.apikey = api_key
		n.priority = Prowly::Notification::Priority::EMERGENCY 
		n.application = "DiskStation Backup Loader" 
		n.event = "No Backups found" 
		n.description = errors_to_send.join("\n")
		n.url = ""
	end
end

rescue Exception => e
	Prowly.notify do |n|
		n.apikey = api_key
		n.priority = Prowly::Notification::Priority::EMERGENCY 
		n.application = "DiskStation Backup Loader" 
		n.event = "Exception" 
		n.description = e.message 
		n.url = ""
	end

end