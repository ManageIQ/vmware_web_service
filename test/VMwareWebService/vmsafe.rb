require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

TARGET_VM = "rich-vmsafe-enabled"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  puts "VM UUID: #{miqVm.vmh['config']['uuid']}"

  puts
  if miqVm.vmsafeEnabled?
    vmsAttr = miqVm.getVmSafeAttributes
    puts "vmsafe.enable:       #{vmsAttr['enable']}"
    puts "vmsafe.agentAddress: #{vmsAttr['agentAddress']}"
    puts "vmsafe.agentPort:    #{vmsAttr['agentPort']}"
    puts "vmsafe.failOpen:     #{vmsAttr['failOpen']}"
    puts "vmsafe.immutableVM:  #{vmsAttr['immutableVM']}"
    puts "vmsafe.timeoutMS:    #{vmsAttr['timeoutMS']}"
  else
    puts "VM is not vmsafe enabled"
  end

  miqVm.setVmSafeAttributes('enable' => "true", 'timeoutMS' => "6000000", 'agentAddress' => "192.168.252.146", 'agentPort' => '8888')
  miqVm.refresh

  puts
  if miqVm.vmsafeEnabled?
    vmsAttr = miqVm.getVmSafeAttributes
    puts "vmsafe.enable:       #{vmsAttr['enable']}"
    puts "vmsafe.agentAddress: #{vmsAttr['agentAddress']}"
    puts "vmsafe.agentPort:    #{vmsAttr['agentPort']}"
    puts "vmsafe.failOpen:     #{vmsAttr['failOpen']}"
    puts "vmsafe.immutableVM:  #{vmsAttr['immutableVM']}"
    puts "vmsafe.timeoutMS:    #{vmsAttr['timeoutMS']}"
  else
    puts "VM is not vmsafe enabled"
  end

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
