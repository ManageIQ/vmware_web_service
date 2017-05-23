require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

unless ARGV.length == 1 && ARGV[0] =~ /(add|remove)/
  $stderr.puts "Usage: #{$0} add | remove"
  exit 1
end

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

targetVm = raise "please define"
targetVmPath = nil
targetVmLpath = nil

# $DEBUG = true

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  miqVm = vim.getVimVmByFilter("config.name" => targetVm)

  targetVmPath = miqVm.dsPath

  puts
  puts "Target VM path: #{targetVmPath}"

  newVmdk = File.join(File.dirname(targetVmPath), "testDisk.vmdk")
  puts "newVmdk = #{newVmdk}"

  puts "********"
  if ARGV[0] == "add"
    miqVm.addDisk(newVmdk, 100)
  else
    miqVm.removeDiskByFile(newVmdk, true)
  end
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
