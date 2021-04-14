require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVimInventory'

SERVER   = raise "please define SERVER"
USERNAME = raise "please define USERNAME"
PASSWORD = raise "please define PASSWORD"

$stderr.sync = true
VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

# $miq_wiredump       = true
vim = MiqVimInventory.new(SERVER, USERNAME, PASSWORD)

puts
puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
puts "API version: #{vim.apiVersion}"
puts

puts "folders.length:              #{vim.folders.length}"
puts "virtualMachines.length:      #{vim.virtualMachines.length}"
puts "virtualMachinesByMor.length: #{vim.virtualMachinesByMor.length}"

vim.disconnect
