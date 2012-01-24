require "language_pack"
require "language_pack/ruby"
require 'open-uri'

class LanguagePack::Rhoconnect < LanguagePack::Rack
  RESOURCE_URL="https://s3.amazonaws.com/rhoconnect-resource/rhoconnect-resource.tar"
  RESOURCE_TAR_FILE="rhoconnect-resource.tar"
  RESOURCE_FILE = "rhoconnect-resource"
  
  def self.use?
    true
  end
  
  def compile
    puts "-----> Installing Rhoconnect-resource..."
    File.open(RESOURCE_TAR_FILE, 'wb') do |fo|
      fo.print open(RESOURCE_URL).read
    end

    # Error checking
    if !File.exists?(RESOURCE_TAR_FILE)
      puts "-----> Error downloading rhoconnect-resource. Please try again..."
      exit 1
    end

    puts "starting to extract resource..."
    system "tar -xmvf #{RESOURCE_TAR_FILE}"
    
    system "cp -r #{RESOURCE_FILE}/* /app/#{RESOURCE_FILE}/"
    #system "mv /app/#{RESOURCE_FILE}/* /app/"
    #system "ls -ltr /app/"
    #system "cat /app/Procfile "
    #system "cat /app/application.rb"
    File.delete RESOURCE_TAR_FILE

    puts "-----> Finished extracting resource"
    
    super
    system "cp -r #{RESOURCE_FILE}/* /app/"
  end
  
end