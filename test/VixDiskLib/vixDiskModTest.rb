require 'disk/MiqDisk'
require 'fs/MiqFS/MiqFS'
require 'VMwareWebService/VixDiskLib/VixDiskLib'
require 'ostruct'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

$log = VMwareWebService.logger

VixDiskLib.init

conParms = {
  :serverName => "",
  :port       => 902,
  :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
  :userName   => "",
  :password   => "",
}

connection = VixDiskLib.connect(conParms)

diskFiles = [
  "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"
]

vixDiskInfo = {
  :connection => connection,
  :fileName   => "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"
}

dInfo = OpenStruct.new
dInfo.vixDiskInfo = vixDiskInfo

disks = []

diskFiles.each do |df|
  puts "*** Disk file: #{df}"
  dInfo.vixDiskInfo[:fileName] = df

  disk = MiqDisk.getDisk(dInfo)
  unless disk
    puts "Failed to open disk"
    exit(1)
  end

  disks << disk

  puts "Disk type: #{disk.diskType}"
  puts "Disk partition type: #{disk.partType}"
  puts "Disk block size: #{disk.blockSize}"
  puts "Disk start LBA: #{disk.lbaStart}"
  puts "Disk end LBA: #{disk.lbaEnd}"
  puts "Disk start byte: #{disk.startByteAddr}"
  puts "Disk end byte: #{disk.endByteAddr}"

  parts = disk.getPartitions

  next unless parts

  foundFs = nil
  i = 1
  parts.each do |p|
    puts "\nPartition #{i}:"
    puts "\tDisk type: #{p.diskType}"
    puts "\tPart partition type: #{p.partType}"
    puts "\tPart block size: #{p.blockSize}"
    puts "\tPart start LBA: #{p.lbaStart}"
    puts "\tPart end LBA: #{p.lbaEnd}"
    puts "\tPart start byte: #{p.startByteAddr}"
    puts "\tPart end byte: #{p.endByteAddr}"
    puts
    fs = MiqFS.getFS(p)
    if fs
      foundFs = fs
      puts "\tFound File System: #{foundFs.fsType}"
    else
      puts "\tNo File System detected."
    end
    i += 1
    puts
  end

  unless foundFs
    puts "No File Systems found."
    exit(0)
  end

  puts "Mounted File System: #{foundFs.fsType}"
  puts "List of #{foundFs.pwd} directory:"
  foundFs.dirForeach { |de| puts "\t#{de}" }
  puts
end

disks.each(&:close)
connection.disconnect
