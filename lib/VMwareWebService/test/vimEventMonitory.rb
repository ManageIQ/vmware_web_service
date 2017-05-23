require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVimEventMonitor'

SERVER   = raise "please define SERVER"
USERNAME = raise "please define USERNAME"
PASSWORD = raise "please define PASSWORD"

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

vimEm = MiqVimEventMonitor.new(SERVER, USERNAME, PASSWORD)

Signal.trap("INT") { vimEm.stop }

puts "vimEm.class: #{vimEm.class}"
puts "#{vimEm.server} is #{(vimEm.isVirtualCenter? ? 'VC' : 'ESX')}"
puts "API version: #{vimEm.apiVersion}"

begin
  thread = Thread.new { vimEm.monitorEventsToStdout }
  thread.join
rescue => err
  puts err.to_s
end

puts "done"
