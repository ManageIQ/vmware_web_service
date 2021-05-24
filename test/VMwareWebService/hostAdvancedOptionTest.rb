require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

# $DEBUG = true

TARGET_HOST = raise "please define"
hMor = nil

vim = MiqVim.new(CLIENT, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqHost = vim.getVimHost(TARGET_HOST)

    raise "Host has no advanced option manager" if !(aom = miqHost.advancedOptionManager)
  
    puts
    puts "*** Advanced option supportedOption:"
    vim.dumpObj(aom.supportedOption)
  
    puts
    puts "*** Advanced option setting:"
    vim.dumpObj(aom.setting)
  
    puts
    puts "*** Advanced option setting for 'Mem:"
    vim.dumpObj(aom.queryOptions('Mem.'))
  
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end
