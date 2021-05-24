require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

if ARGV.length != 3
  $stderr.puts "Usage: #{$0} server username password"
  exit 1
end

server    = ARGV[0]
username  = ARGV[1]
password  = ARGV[2]

begin
  puts "Connecting to #{server}..."
  vim = MiqVim.new(server, username, password)
  puts "Done."

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  puts "VMs with EVM snapshots:"
  vim.virtualMachinesByMor.each_value do |vm|
    miqVm = vim.getVimVmByMor(vm['MOR'])
    if miqVm.hasSnapshot?(MiqVimVm::EVM_SNAPSHOT_NAME)
      puts "\t" + miqVm.name
    end
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
