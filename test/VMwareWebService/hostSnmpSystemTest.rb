require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

TARGET_HOST = raise "please define"
hMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    puts "Host name: #{TARGET_HOST}"
    puts
    
    # puts "**** Host services:"
    # vim.dumpObj(vim.hostSystems[TARGET_HOST]['config']['service'])
    # puts "****************************************************************"
    # puts
  
    miqHost = vim.getVimHost(TARGET_HOST)

    # vim.dumpObj(vim.getMoProp(miqHost.hMor))
    # exit

    puts "Host name: #{miqHost.name}"
    puts

    puts "**** configManager:"
    vim.dumpObj(miqHost.configManager)
    puts "****************************************************************"
    puts
  
    ss = miqHost.snmpSystem
  
    si = ss.snmpSystem
  
    puts "**** snmpSystem:"
    vim.dumpObj(si)
    puts "****************************************************************"
    puts
  
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end
