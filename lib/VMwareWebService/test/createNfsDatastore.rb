require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$stdout.sync = true
# $miq_wiredump = true

TARGET_HOST = raise "please define"

VOL_NAME  = "api_test_vol1"
REMOTE_HOST = ""
REMOTE_PATH = "/vol/#{VOL_NAME}"
LOCAL_PATH  = VOL_NAME.tr('_', '-') # Datastore names cannot contain underscores
ACCESS_MODE = "readWrite"

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  miqHost = vim.getVimHost(TARGET_HOST)
  puts "Got object for host: #{miqHost.name}"

  miqDss = miqHost.datastoreSystem

  puts
  puts "Creating datastore: #{LOCAL_PATH}..."
  miqDss.createNasDatastore(REMOTE_HOST, REMOTE_PATH, LOCAL_PATH, ACCESS_MODE)
  puts "done."

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
