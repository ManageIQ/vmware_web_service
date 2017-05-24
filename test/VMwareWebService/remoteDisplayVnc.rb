require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

TARGET_VM = "testxav"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  puts "VM UUID: #{miqVm.vmh['config']['uuid']}"

  puts
  if miqVm.remoteDisplayVncEnabled?
    vmsAttr = miqVm.getRemoteDisplayVncAttributes
    puts "RemoteDisplay.vnc.enabled:  #{vmsAttr['enabled']}"
    puts "RemoteDisplay.vnc.key:      #{vmsAttr['key']}"
    puts "RemoteDisplay.vnc.password: #{vmsAttr['password']}"
    puts "RemoteDisplay.vnc.port:     #{vmsAttr['port']}"
  else
    puts "VM RemoveDisplay.vnc is not enabled"
  end

  miqVm.setRemoteDisplayVncAttributes('enabled' => "true", 'password' => PASSWORD, 'port' => 5901)
  miqVm.refresh

  puts
  if miqVm.remoteDisplayVncEnabled?
    vmsAttr = miqVm.getRemoteDisplayVncAttributes
    puts "RemoteDisplay.vnc.enabled:  #{vmsAttr['enabled']}"
    puts "RemoteDisplay.vnc.key:      #{vmsAttr['key']}"
    puts "RemoteDisplay.vnc.password: #{vmsAttr['password']}"
    puts "RemoteDisplay.vnc.port:     #{vmsAttr['port']}"
  else
    puts "VM RemoveDisplay.vnc vnc is not enabled"
  end

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
