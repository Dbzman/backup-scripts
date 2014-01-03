#!/opt/bin/ruby

require 'rubygems'
require 'net/sftp'
require 'json'
require 'openssl'
require 'prowly'

# ---- configuration ----
begin

config_file = File.read("#{File.dirname(__FILE__)}/config.json")

config = JSON.parse(config_file)

api_key = "38958a23d7815509541df3837f58897a543444a1"


# ---- preparation ----
current_time = Time.new
current_time = current_time.strftime "%Y-%m-%d"
BACKUP_PATH = "#{config['backup_path']}/#{current_time}"
DELETE_AFTER_DOWNLOAD = config['delete_after_download']
puts "BACKUP_PATH: #{BACKUP_PATH}"
puts DELETE_AFTER_DOWNLOAD if DELETE_AFTER_DOWNLOAD == false

errors_to_send = []

# create a new folder with current_time
if !File.exists?(BACKUP_PATH)
	Dir.mkdir(BACKUP_PATH)
	puts "folder #{current_time} created"
else 
	puts "folder #{current_time} already exists, skipping..."
end


# ---- remote work ---- 
config['remotes'].each do |remote|	
	Net::SFTP.start(remote['url'], remote['username'], :password => remote['password']) do |sftp|
		puts "downloading from host #{remote['name']}"
		remote['dirs'].each do |remote_dir|

			downloaded_files = 0
			sftp.dir.foreach(remote_dir) do |entry|
				if !File.exists?("#{BACKUP_PATH}/#{remote['name']}")
					Dir.mkdir("#{BACKUP_PATH}/#{remote['name']}")
					puts "folder #{remote['name']} created"
				end

				if (!entry.name.start_with?(".") and entry.name.include?("."))
					puts "downloading #{entry.name}"
					downloaded_files += 1
					sftp.download!("#{remote_dir}/#{entry.name}", "#{BACKUP_PATH}/#{remote['name']}/#{entry.name}")
					if (DELETE_AFTER_DOWNLOAD)
						sftp.remove!("#{remote_dir}/#{entry.name}")
						puts "removed #{entry.name}"
					end
				end

				
			end
			if (downloaded_files == 0)
				puts "folder '#{remote_dir}' of host '#{remote['name']}' is empty!"
				errors_to_send << "- folder '#{remote_dir}' of host '#{remote['name']}' is empty!"
			end
		end
	end
end

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