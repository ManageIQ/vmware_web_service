require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$stdout.sync = true
# $miq_wiredump = true

TARGET_HOST = raise "please define"
DS_NAME   = "nas-ds-add-test"

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  puts "virtualApps from inventoryHash:"
  vim.inventoryHash['VirtualApp'].each do |v|
    puts "\t" + v
  end
  puts

  vmh = vim.virtualMachinesByMor
  vma = vim.inventoryHash['VirtualMachine']

  puts "virtualAppsByMor:"
  vim.virtualAppsByMor.each do |mor, va|
    puts "\t#{mor}\t-> #{va.name} (parent = #{va.parent})"
    prp = vim.resourcePoolsByMor[va.parent] || vim.virtualAppsByMor[va.parent]
    puts "\t\tParent has child = #{prp.resourcePool.include?(mor)}"
    puts "\t\tVMs:"
    va.vm.each do |vmMor|
      puts "\t\t\t#{vmMor} (In virtualMachinesByMor = #{!vmh[vmMor].nil?}) (In inventoryHash = #{vma.include?(vmMor)})"
    end
  end

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
