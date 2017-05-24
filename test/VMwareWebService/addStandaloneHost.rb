require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true
TARGET_HOST   = ""
HOST_USERNAME = ""
HOST_PASSWORD = ""
FOLDER_NAME   = ""

miqCluster  = nil
miqHost   = nil

broker = MiqVimBroker.new(:client)
vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)

begin

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  puts
  puts "Folders: #{vim.folders.keys.join(', ')}"
  miqFolder = vim.getVimFolder(FOLDER_NAME)
  puts "Found folder: #{miqFolder.name}"

  puts
  puts "Adding host: #{TARGET_HOST}..."
  crMor = miqFolder.addStandaloneHost(TARGET_HOST, HOST_USERNAME, HOST_PASSWORD)
  puts "Host added."

  newHostMor = vim.computeResourcesByMor[crMor].host.first

  puts
  puts "New host MOR: #{newHostMor}"

  miqHost = vim.getVimHostByMor(newHostMor)
  puts "Got object for new host: #{miqHost.name}"

  if miqHost.inMaintenanceMode?
    puts "New host is in Maintenance Mode"
    puts "\texiting Maintenance Mode..."
    miqHost.exitMaintenanceMode
    puts "\tdone."
    puts "inMaintenanceMode? = #{miqHost.inMaintenanceMode?}"
  end
# vim.dumpObj(miqHost.hh)

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  miqCluster.release if miqCluster
  vim.disconnect
end
