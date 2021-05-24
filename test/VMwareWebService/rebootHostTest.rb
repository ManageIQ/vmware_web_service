require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

# $miq_wiredump = true
TARGET_HOST   = raise "please define"
HOST_USERNAME = ""
HOST_PASSWORD = ""
CLUSTER_NAME  = ""

miqCluster  = nil
miqHost   = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    puts
    miqHost = vim.getVimHost(TARGET_HOST)
    puts "Got object for host: #{miqHost.name}"
  
    unless miqHost.rebootSupported?
      puts "Host does not support reboot"
      exit
    end
  
    puts
    puts "Rebooting host..."
    miqHost.rebootHost
    puts "done."
  

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqCluster.release if miqCluster
  vim.disconnect
end
