require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/VimTypes'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$miq_wiredump = false

$stderr.sync = true
$stdout.sync = true

HOST_NAME   = raise "please define"
NEW_PORTGROUP = 'portgroup2'

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  vimHost = vim.getVimHostByFilter('summary.config.name' => HOST_NAME)
  # vim.dumpObj(vim.hostSystems[HOST_NAME])
  # exit

  hmor = vim.hostSystems[HOST_NAME]['MOR']

  #
  # Get the DVS info for a given host.
  #
  dvs = vimHost.dvsConfig
  vim.dumpObj(dvs)
  puts

  #
  # List the names of the non-uplink portgroups.
  #
  nupga = vimHost.dvsPortGroupByFilter('uplinkPortgroup' => 'false')
  puts "Available DVS portgroups:"
  nupga.each { |nupg| puts "\t" + nupg.portgroupName }
  puts

  dpg = vimHost.dvsPortGroupByFilter('portgroupName' => NEW_PORTGROUP, 'uplinkPortgroup' => 'false').first
  switchUuid    = dpg.switchUuid
  portgroupName = dpg.portgroupName
  portgroupKey  = dpg.portgroupKey
  puts "portgroupName: #{portgroupName}, portgroupKey: #{portgroupKey}, switchUuid: #{switchUuid}"

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  vimHost.release if vimHost
  vim.disconnect if vim
end
