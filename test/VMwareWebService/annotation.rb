require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

TARGET_VM = raise "please define"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  puts
  puts "** VM annotation start:"
  puts miqVm.annotation
  puts "** VM annotation end"

  puts
  puts "Custom values:"
  miqVm.customValues.each { |k, v| puts "\t#{k} => #{v}" }

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
