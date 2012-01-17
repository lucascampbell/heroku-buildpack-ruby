require 'open-uri'
class LanguagePack::Rhconnect < LanguagePack::Rack
  RESOURCE_URL="https://s3.amazonaws.com/rhoconnect-resource/rhoconnect-resource.tar"
  RESOURCE_TAR_FILE="rhoconnect-resource.tar"
  RESOURCE_FILE = "rhoconnect-resource"
  
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
    #system "mv #{RESOURCE_FILE} /app/"
    File.delete RESOURCE_TAR_FILE

    system "pwd;ls -altr /app;cat /app/config.ru"

    puts "-----> Finished extracting resource"
    super
  end
  
end