require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

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

  miqHost = vim.getVimHost(TARGET_HOST)

  puts "*** systemInfo"
  vim.dumpObj(miqHost.hh['hardware']['systemInfo'])
  exit

  puts "*** quickStats"
  qs = miqHost.quickStats
  vim.dumpObj(qs)
  exit

  vim.dumpObj(miqHost.hh['config']['dateTimeInfo'])
  puts "miqHost: #{miqHost.class}"
  exit

  puts "Host name: #{miqHost.name}"
  puts
  puts "**** fileSystemVolume:"
  vim.dumpObj(miqHost.fileSystemVolume)
  puts
  puts "**** storageDevice:"
  vim.dumpObj(miqHost.storageDevice)
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end
