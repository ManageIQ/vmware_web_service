require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$stderr.sync = true
$stdout.sync = true

TARGET_VM      = "rpo-clone-src"
sVmMor = nil
miqVm = nil

vimDs = nil
dsName = "DEVOpen-E0"

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  vmMor = miqVm.vmMor
  rpMor = miqVm.vmh.resourcePool
  hsMor = miqVm.vmh.summary.runtime.host
  vmPath  = miqVm.vmh.summary.config.vmPathName

  puts "Target VM: #{TARGET_VM}, MOR: #{vmMor}"
  puts "Target VM path: #{vmPath}"
  puts "VM resource pool MOR: #{rpMor}"
  puts "VM host MOR: #{hsMor}"
  puts

  miqVmf = vim.getVimFolderByFilter('childType' => 'VirtualMachine', 'childEntity' => vmMor)
  # vim.dumpObj(miqVmf.fh)

  puts "Unregistering #{TARGET_VM}..."
  miqVm.unregister
  puts "Done."

  puts
  puts "Registering VM #{TARGET_VM}..."
  miqVmf.registerVM(vmPath, TARGET_VM, rpMor, hsMor, false)
  puts "done."
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  miqVm.release if miqVm
  vim.disconnect if vim
end
