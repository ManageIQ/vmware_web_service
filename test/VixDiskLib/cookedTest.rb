require 'VMwareWebService/VixDiskLib/VixDiskLib'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

diskFiles = [
  "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"
]

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

puts "VIXDISKLIB_FLAG_OPEN_UNBUFFERED  = #{VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_UNBUFFERED}"
puts "VIXDISKLIB_FLAG_OPEN_SINGLE_LINK = #{VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_SINGLE_LINK}"
puts "VIXDISKLIB_FLAG_OPEN_READ_ONLY   = #{VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY}"
puts "VIXDISKLIB_CRED_UID              = #{VixDiskLib_raw::VIXDISKLIB_CRED_UID}"
puts "VIXDISKLIB_CRED_SESSIONID        = #{VixDiskLib_raw::VIXDISKLIB_CRED_SESSIONID}"
puts "VIXDISKLIB_CRED_UNKNOWN          = #{VixDiskLib_raw::VIXDISKLIB_CRED_UNKNOWN}"
puts "VIXDISKLIB_SECTOR_SIZE           = #{VixDiskLib_raw::VIXDISKLIB_SECTOR_SIZE}"
puts

VixDiskLib.init(->(s) { puts "INFO: #{s}" },
                ->(s) { puts "WARN: #{s}" },
                ->(s) { puts "ERROR: #{s}" })

conParms = {
  :serverName => "",
  :port       => 902,
  :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
  :userName   => "",
  :password   => "",
}

connection = VixDiskLib.connect(conParms)

vDisks = []

n = 1
diskFiles.each do |vmdk|
  puts "*** #{n} *** VMDK: #{vmdk}"
  vDisk = connection.getDisk(vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
  vDisks << vDisk

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
  n += 1

  break
end

vDisks.each(&:close)
connection.disconnect
