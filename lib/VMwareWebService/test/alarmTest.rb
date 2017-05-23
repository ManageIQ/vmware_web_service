require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

TARGET_VM = raise "please define"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
  aMor = miqVm.addMiqAlarm
  puts "aMor = #{aMor} <#{aMor.vimType}>"
  miqVm.removeMiqAlarm
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end
