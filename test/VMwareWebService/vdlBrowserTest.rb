require 'manageiq-gems-pending'

require 'VMwareWebService/MiqVim'
require 'VMwareWebService/VixDiskLib/VixDiskLib'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

$stderr.sync = true
$stdout.sync = true

# $DEBUG = true
# MiqVimClientBase.wiredump_file = "clone.txt"

SRC_VM      = "rpo-test2"

readRanges = [
  0,  256,
  0,  512,
  256,  512,
  512,  256,
  512,  512,
  256, 1024,
  1280,  256,
  1280,  512,
  1280, 1024
]

vDisk = nil
vdlc  = nil

begin
  t0 = Time.now

  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  svm = vim.virtualMachinesByFilter("config.name" => SRC_VM)
  if svm.empty?
    puts "VM: #{SRC_VM} not found"
    exit
  end

  puts "#{SRC_VM} vmPathName:      #{svm[0]['summary']['config']['vmPathName']}"
  puts "#{SRC_VM} vmLocalPathName: #{svm[0]['summary']['config']['vmLocalPathName']}"

  sVmMor = svm[0]['MOR']
  miqVm = vim.getVimVmByMor(sVmMor)

  puts "VM: #{miqVm.name}, HOST: #{miqVm.hostSystem}"
  puts

  diskFile = miqVm.getCfg['scsi0:0.filename']
  ldiskFile = vim.localVmPath(diskFile)
  puts "diskFile: #{diskFile}"
  puts "ldiskFile: #{ldiskFile}"
  puts

  if vim.isVirtualCenter?
    puts "Calling: miqVm.vdlVcConnection"
    vdlc = miqVm.vdlVcConnection
    vDisk = vdlc.getDisk(diskFile, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
  else
    vdlc = vim.vdlConnection
    vDisk = vdlc.getDisk(ldiskFile, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
  end

  dinfo = vDisk.info
  puts
  puts "Disk info:"
  dinfo.each { |k, v| puts "\t#{k} => #{v}" }
  puts

  readRanges.each_slice(2) do |start, len|
    puts "Read test: start = #{start}, len = #{len} (bytes)"
    startSector, startOffset = start.divmod(vDisk.sectorSize)
    endSector = (start + len - 1) / vDisk.sectorSize
    numSector = endSector - startSector + 1
    puts "\tstartSector = #{startSector}, numSector = #{numSector}, startOffset = #{startOffset}"

    rBData = vDisk.bread(startSector, numSector)
    puts "\tBlock read #{rBData.length} bytes of data."

    rCData = vDisk.read(start, len)
    puts "\tByte read #{rCData.length} bytes of data."

    if rCData != rBData[startOffset, len]
      puts "\t\t*** Block and byte data don't match"
    else
      puts "\t\tData check passed"
    end
    puts
  end

rescue => err
  puts err
  puts err.class.to_s
  puts err.backtrace.join("\n")
ensure
  vDisk.close if vDisk
  vdlc.disconnect if vdlc
end
