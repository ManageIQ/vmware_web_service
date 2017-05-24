require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

broker = MiqVimBroker.new(:client)
vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    objs = []
  
    vim.inventoryHash['VirtualMachine'].each  { |mor| objs << vim.getVimVmByMor(mor) }
    vim.inventoryHash['HostSystem'].each    { |mor| objs << vim.getVimHostByMor(mor) }
    vim.inventoryHash['Folder'].each      { |mor| objs << vim.getVimFolderByMor(mor) }
    vim.inventoryHash['Datastore'].each     { |mor| objs << vim.getVimDataStoreByMor(mor) }
  
    puts
    puts "Object counts:"
    broker.objectCounts.each { |k, v| puts "\t#{k}: #{v}"}
  
    objs.each(&:release)
  
    puts
    puts "Object counts:"
    broker.objectCounts.each { |k, v| puts "\t#{k}: #{v}"}
  
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end
