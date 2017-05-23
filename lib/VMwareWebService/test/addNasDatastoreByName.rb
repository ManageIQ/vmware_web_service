require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$stdout.sync = true
# $miq_wiredump = true

TARGET_HOST = raise "please define"

DS_NAME   = "nas-ds-add-test"

begin

  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  nasDsa = vim.dataStoresByFilter("summary.type" => "NFS")
  puts "NAS Datastores:"
  nasDsa.each { |ds| puts "\t#{ds.summary.name} (#{ds.summary.url})" }
  puts
  puts "Target datastore: #{DS_NAME}"
  puts

  miqHost = vim.getVimHost(TARGET_HOST)
  puts "Got object for host: #{miqHost.name}"

  miqDss = miqHost.datastoreSystem

  puts
  puts "Adding datastore: #{DS_NAME}..."
  miqDss.addNasDatastoreByName(DS_NAME)
  puts "done."

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
