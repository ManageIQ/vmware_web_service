$:.push("#{File.dirname(__FILE__)}/..")

require "VixDiskLib_raw"

vmdk =  "/vmfs/volumes/StarM2-LUN1/VMmini-101/VMmini-101.vmdk"

conParms = {
  :serverName => "",
  :port       => 902,
  :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
  :userName   => "",
  :password   => "",
}

VixDiskLib_raw.init(lambda { |s| puts "INFO: #{s}" },
                    lambda { |s| puts "WARN: #{s}" },
                    lambda { |s| puts "ERROR: #{s}" }, nil)

connection = VixDiskLib_raw.connect(conParms)
dHandle = VixDiskLib_raw.open(connection, vmdk, VixDiskLib_raw::VIXDISKLIB_FLAG_OPEN_READ_ONLY)
dinfo = VixDiskLib_raw.getInfo(dHandle)

puts
puts "Disk info:"
dinfo.each { |k, v| puts "\t#{k} => #{v}" }
puts

# nReads = 500000
nReads = 500

bytesRead = 0
t0 = Time.now

(0...nReads).each do |rn|
  rData = VixDiskLib_raw.read(dHandle, rn, 1)
  bytesRead += rData.length
end

t1 = Time.now
bps = bytesRead / (t1 - t0)

puts "Read throughput: #{bps} B/s"

VixDiskLib_raw.close(dHandle)

VixDiskLib_raw.disconnect(connection)
VixDiskLib_raw.exit
