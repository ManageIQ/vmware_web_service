require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true
TARGET_HOST   = raise "please define"
HOST_USERNAME = ""
HOST_PASSWORD = ""
CLUSTER_NAME  = ""

miqCluster  = nil
miqHost   = nil

broker = MiqVimBroker.new(:client)
vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)

begin
  
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    puts
    miqHost = vim.getVimHost(TARGET_HOST)
    puts "Got object for host: #{miqHost.name}"
  
    unless miqHost.shutdownSupported?
      puts "Host does not support shutdown"
      exit
    end
  
    puts
    puts "Shutting down host..."
    miqHost.shutdownHost
    puts "done."
  

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqCluster.release if miqCluster
  vim.disconnect
end
