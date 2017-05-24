require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

TARGET_VM = raise "please define"
miqVm = nil

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  # vim.logger = $stdout

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  # puts miqVm.acquireMksTicket

  puts
  puts "Connection State: #{miqVm.connectionState}"
  puts "Power State:      #{miqVm.powerState}"
  puts

  thinDevs = miqVm.devicesByFilter("backing.thinProvisioned" => "true")

  if thinDevs.empty?
    puts "#{TARGET_VM} has no thin provisioned disks."
    exit
  end

  vimDs = nil
  puts "Thin provisioned disks for #{TARGET_VM}:"
  thinDevs.each do |d|
    path = d['backing']['fileName']
    dsrPath = vim.dsRelativePath(path)
    dir, file = File.split(dsrPath)

    #
    # Just in case all the files aren't on the same datastore.
    #
    if vimDs
      if vimDs.dsMor != d['backing']['datastore']
        vimDs.release
        vimDs = vim.getVimDataStoreByMor(d['backing']['datastore'])
      end
    else
      vimDs = vim.getVimDataStoreByMor(d['backing']['datastore'])
      puts
      puts "\t(Datastore capacity:           #{vimDs.capacityBytes} bytes)"
      puts "\t(Datastore free space:         #{vimDs.freeBytes} bytes)"
      if vimDs.uncommitted
        deltaCommit = vimDs.freeBytes - vimDs.uncommitted
        puts "\t(Datastore uncommitted space:  #{vimDs.uncommitted} bytes)"
        if deltaCommit >= 0
          puts "\t(Datastore under committed by: #{deltaCommit} bytes)"
        else
          puts "\t(Datastore over committed by: #{-deltaCommit} bytes)"
        end
      end
      puts
    end

    fo = vimDs.dsVmDiskFileSearch(file, dir, false, false).first

    puts "\tPath: #{path}"
    puts "\t\tFile: #{file}"
    puts "\t\tCapacity:  #{d['capacityInKB']} KB"
    puts "\t\tFile size: #{fo.fileSize.to_i / 1024} KB" if fo
    puts
  end

rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  vimDs.release if vimDs
  miqVm.release if miqVm
  vim.disconnect if vim
end
