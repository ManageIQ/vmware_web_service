require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

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
  
    #
    # It appears that this returns true for a VM running ESX,
    # even though it doesn't seem to support standby.
    #
    unless miqHost.standbySupported?
      puts "Host does not support standby"
      exit
    end
  
    puts
    puts "Putting host in StandBy Mode..."
    miqHost.powerDownHostToStandBy
    puts "done."
  

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqCluster.release if miqCluster
  vim.disconnect
end
