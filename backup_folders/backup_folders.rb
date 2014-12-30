#!/usr/bin/env ruby
ENV['GEM_HOME'] = '/kunden/129007_65817/.gem'
ENV['GEM_PATH'] = '/kunden/129007_65817/.gem:/usr/lib/ruby/gems/1.8'

$stdout.reopen("#{File.dirname(__FILE__)}/backup_log.log", "w")
$stderr.reopen("#{File.dirname(__FILE__)}/backup_error.log", "w")

require 'rubygems'
require 'json'
require 'date'

puts "starting backup"

config_file = File.read("#{File.dirname(__FILE__)}/config.json")

config = JSON.parse(config_file)

BASE_PATH = config['base_path']
BACKUP_PATH = "#{config['base_path']}#{config['backup_path']}"
BACKUP_EXTENSION = config['backup_extension']

timestamp = Time.now.to_i

config['folders'].each do |folder|
	puts "backing up '#{folder['name']}'"

	command = "cd #{BASE_PATH} && tar -cvzpf #{BACKUP_PATH}/#{timestamp}_#{folder['name']}#{BACKUP_EXTENSION}"	
	
	if folder['paths'].kind_of?(Array)

	  folder['paths'].each do |folder_to_backup|
	  	puts "folder_to_backup #{BASE_PATH}#{folder_to_backup}"
	  	command += " #{folder_to_backup}"
	  end
	end
	puts "excuting #{command}"
	system command
end