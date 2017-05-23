require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

TARGET_VM = "rpo-test2"
vmMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  puts "******* Memory *******"

  origMem = miqVm.getMemory
  puts "Memory: #{origMem}"

  newMem = (origMem == 256 ? 512 : 256)
  puts "Setting memory to #{newMem}"

  miqVm.setMemory(newMem)
  puts "Memory: #{miqVm.getMemory}"

  puts "******* CPUs *******"

  origCPUs = miqVm.getNumCPUs
  puts "CPUs: #{miqVm.getNumCPUs}"

  newCPUs = (origCPUs == 1 ? 2 : 1)
  puts "Setting CPUs to #{newCPUs}"

  miqVm.setNumCPUs(newCPUs)
  puts "CPUs: #{miqVm.getNumCPUs}"
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
