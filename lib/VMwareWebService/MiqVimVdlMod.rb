
module MiqVimVdlConnectionMod
  #
  # Return a VixDiskLib connection object for the same server that VIM is connected to.
  #
  def vdlConnection
    require 'VMwareWebService/VixDiskLib/VixDiskLib'
    VixDiskLib.init(->(s) { logger.info  "VMware(VixDiskLib): #{s}" },
                    ->(s) { logger.warn  "VMware(VixDiskLib): #{s}" },
                    ->(s) { logger.error "VMware(VixDiskLib): #{s}" })
    $log.info "MiqVimVdlConnectionMod.vdlConnection: server - #{@server}"
    VixDiskLib.connect(:serverName => server,
                       :port       => 902,
                       :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
                       :userName   => username,
                       :password   => password)
  end

  def closeVdlConnection(connection)
    logger.info "MiqVimMod.closeVdlConnection: #{connection.serverName}"
    connection.disconnect
  end
end # module MiqVimVdlConnectionMod

module MiqVimVdlVcConnectionMod
  #
  # Return a VixDiskLib connection object for the VC server that VIM is connected to.
  # The connection is specific to this VM, and should be closed by the caller when it
  # has finished accessing the VM's disk files.
  #
  def vdlVcConnection
    require 'VMwareWebService/VixDiskLib/VixDiskLib'

    VixDiskLib.init(->(s) { logger.info  "VMware(VixDiskLib): #{s}" },
                    ->(s) { logger.warn  "VMware(VixDiskLib): #{s}" },
                    ->(s) { logger.error "VMware(VixDiskLib): #{s}" })

    $log.info "MiqVimVdlVcConnectionMod.vdlVcConnection: server - #{invObj.server}"
    thumb_print = if invObj.isVirtualCenter?
                    VcenterThumbPrint.new(invObj.server)
                  else
                    ESXThumbPrint.new(invObj.server, invObj.username, invObj.password)
                  end

    sha1 = thumb_print.to_sha1
    VixDiskLib.connect(:serverName => invObj.server,
                       :vmxSpec    => vixVmxSpec,
                       :thumbPrint => sha1,
                       :port       => 902,
                       :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
                       :userName   => invObj.username,
                       :password   => invObj.password)
  end
end # module MiqVimVdlVcConnectionMod
