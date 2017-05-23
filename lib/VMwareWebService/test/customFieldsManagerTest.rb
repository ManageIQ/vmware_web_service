require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $DEBUG = true
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
TARGET_VM = ""
TARGET_HOST = ""

begin
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  #
  # Test the raw CustomFieldsManager
  #
  miqCfm = vim.getMiqCustomFieldsManager

  fields = miqCfm.field
  if fields
    vim.dumpObj(fields)
  else
    puts "No custom fields currently defined"
  end
  puts

  fKey = miqCfm.getFieldKey('EVM Policy', 'VirtualMachine')

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
  puts "Target VM: #{TARGET_VM}, MOR: #{miqVm.vmMor}"
  puts

  # Test raw method.
  miqCfm.setField(miqVm.vmMor, fKey, 'Test data')

  #
  # Test VM-specific method.
  #
  miqVm.setCustomField('EVM Policy', 'Test data VM')

  #
  # Now, test for host.
  #
  miqHost = vim.getVimHost(TARGET_HOST)
  miqHost.setCustomField('EVM Policy', 'Test data HOST')
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  miqCfm.release if miqCfm
  vim.disconnect
end
