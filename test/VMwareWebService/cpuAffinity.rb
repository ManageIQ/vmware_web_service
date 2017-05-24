require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

TARGET_VM = "rpo-vmsafe"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  puts
  aa = nil
  if miqVm.vmh['config']['cpuAffinity'] && miqVm.vmh['config']['cpuAffinity']['affinitySet']
    aa = miqVm.vmh['config']['cpuAffinity']['affinitySet']
    puts "CPU affinity for #{TARGET_VM}:"
    aa.each { |cpu| puts "\t#{cpu}" }
  else
    puts "VM: #{TARGET_VM} has no CPU affility"
  end
  puts

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
