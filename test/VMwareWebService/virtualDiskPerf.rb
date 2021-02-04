require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

$stdout.sync = true
$stderr.sync = true

$miq_wiredump = false

vm = "netapp-sim-host2"

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  puts "*** Calling: getVimPerfHistory..."
  miqPh = vim.getVimPerfHistory
  puts "*** done."

  puts "*** Calling: cInfoMap..."
  cInfoMap = miqPh.cInfoMap
  puts "*** done."
  # puts "*** Counter info for group 'virtualDisk':"
  # vim.dumpObj(cInfoMap['virtualDisk'])
  # puts

  puts "*** Calling: virtualMachinesByFilter('config.name' => #{vm})..."
  vmo = vim.virtualMachinesByFilter("config.name" => vm)
  if vmo.empty?
    puts "VM: #{vm} not found"
    exit
  end
  vmMor = vmo[0]['MOR']
  puts "*** done."

  puts "*** Calling: queryProviderSummary for #{vm}..."
  psum = miqPh.queryProviderSummary(vmMor)
  puts "*** done."

  read      = miqPh.getCounterInfo('virtualDisk', 'read',         'average',  'rate')
  write     = miqPh.getCounterInfo('virtualDisk', 'write',          'average',  'rate')
  numberRead    = miqPh.getCounterInfo('virtualDisk', 'numberReadAveraged',   'average',  'rate')
  numberWrite   = miqPh.getCounterInfo('virtualDisk', 'numberWriteAveraged',  'average',  'rate')
  readLatency   = miqPh.getCounterInfo('virtualDisk', 'totalReadLatency',   'average',  'absolute')
  writeLatency  = miqPh.getCounterInfo('virtualDisk', 'totalWriteLatency',    'average',  'absolute')

  puts
  puts "Metrics for virtualDisk:"
  [read, write, numberRead, numberWrite, readLatency, writeLatency].each do |ci|
    puts "\t#{ci.nameInfo['key']}[#{ci['key']}](#{ci.unitInfo.label}):\t#{ci.nameInfo.summary}"
  end

  metricId =  [
    {:counterId => read['key'],      :instance => "*"},
    {:counterId => write['key'],     :instance => "*"},
    {:counterId => numberRead['key'],    :instance => "*"},
    {:counterId => numberWrite['key'],   :instance => "*"},
    {:counterId => readLatency['key'],   :instance => "*"},
    {:counterId => writeLatency['key'],  :instance => "*"}
  ]
  ea = [{:entity => vmMor,  :intervalId => psum['refreshRate'], :metricId => metricId}]

  pcm = miqPh.queryPerfMulti(ea)
  puts
  vim.dumpObj(pcm)
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  miqPh.release if miqPh
  vim.disconnect if vim
end
