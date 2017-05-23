require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$stdout.sync = true
# $miq_wiredump = true

TARGET_HOST = raise "please define"

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  hh = vim.hostSystems[TARGET_HOST]
  dataStores = vim.dataStoresByMor

  puts "**** Host datastores:"
  # vim.dumpObj(hh['datastore'])
  # exit

  hh['datastore'].each do |dsMor|
    puts "**** #{dataStores[dsMor]['summary']['name']} -> #{dsMor}"
    vim.dumpObj(dataStores[dsMor])
    info = vim.getMoProp(dsMor, 'info')
    puts "  *********** INFO:"
    vim.dumpObj(info, 1)
    puts
  end

  scsiLun = vim.getMoProp(hh['MOR'], "config.storageDevice.scsiLun")['config']['storageDevice']['scsiLun']
  puts
  puts "*********** scsiLun:"
  vim.dumpObj(scsiLun)

  scsiTopology = vim.getMoProp(hh['MOR'], "config.storageDevice.scsiTopology")['config']['storageDevice']['scsiTopology']
  puts
  puts "*********** scsiTopology:"
  vim.dumpObj(scsiTopology)
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
