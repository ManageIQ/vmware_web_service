require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

# $DEBUG = true

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

    #
    # Test the AlarmManager
    #
    miqAm = vim.getVimAlarmManager

    alarms = miqAm.getAlarm
    if alarms
      vim.dumpObj(alarms)
    else
      puts "No alarms currently defined"
    end
  
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqAm.release if miqAm
  vim.disconnect
end
