require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVimCoreUpdater'

SERVER   = raise "please define SERVER"
USERNAME = raise "please define USERNAME"
PASSWORD = raise "please define PASSWORD"

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

vimEm = MiqVimCoreUpdater.new(SERVER, USERNAME, PASSWORD)

Signal.trap("INT") { vimEm.stop }

begin
  thread = Thread.new do
    vimEm.monitorUpdates do |mor, ph|
      puts "Object: #{mor} (#{mor.vimType})"
      ph.each { |k, v| puts "\t#{k}:\t#{v}" } unless ph.nil?
    end
  end
  thread.join
rescue => err
  puts err.to_s
end
