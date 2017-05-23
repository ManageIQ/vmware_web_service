require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

VimTestMethods = [
  :virtualMachines,
  :virtualMachinesByMor,
  :virtualMachineByMor,
  :computeResources,
  :computeResourcesByMor,
  :computeResourceByMor,
  :clusterComputeResources,
  :clusterComputeResourcesByMor,
  :clusterComputeResourceByMor,
  :resourcePools,
  :resourcePoolsByMor,
  :resourcePoolByMor,
  :folders,
  :foldersByMor,
  :folderByMor,
  :datacenters,
  :datacentersByMor,
  :datacenterByMor,
  :hostSystems,
  :hostSystemsByMor,
  :hostSystemByMor,
  :dataStores,
  :dataStoresByMor,
  :dataStoreByMor
]

SelectionSpec = {}

#
# Set SelectionSpec for all broker instances and their connections.
# Must be set in the broker server.
# MiqVimBroker.setSelector(SelectionSpec)

TARGET_HOST = raise "please define"
hMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
  
    VimTestMethods.each_slice(3) do |objs, objsbymor, objbymor|
      rv = vim.send(objsbymor, objs)
      next if rv.values.empty?
      mor = rv.values.first['MOR']
      
      puts
      puts "*** #{objsbymor} START"
      vim.dumpObj(rv)
      puts "*** #{objsbymor} END"
      
      rv = vim.send(objbymor, mor, objs)
      
      puts
      puts "*** #{objbymor} START"
      vim.dumpObj(rv)
      puts "*** #{objbymor} END"
      
      rv = vim.send(objs, objs)
    end

    miqHost = vim.getVimHost(TARGET_HOST)

    puts
    puts "*** storageDevice START"
    sd = miqHost.storageDevice(:storageDeviceSS)
    vim.dumpObj(sd)
    puts "*** storageDevice END"
  
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end
