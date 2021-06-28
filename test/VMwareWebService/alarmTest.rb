require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

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
