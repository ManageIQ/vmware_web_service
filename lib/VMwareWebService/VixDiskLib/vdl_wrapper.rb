require 'drb/drb'
require 'sync'
require 'ffi-vix_disk_lib/api_wrapper'
require 'VMwareWebService/VimTypes'
require 'VMwareWebService/logging'
require 'time'

VixDiskLibApi = FFI::VixDiskLib::ApiWrapper
class VdlWrapper
  extend FFI::VixDiskLib::ApiWrapper
  include DRb::DRbUndumped
  include VMwareWebService::Logging

  @initialized       = false
  @server_disk_count = 0
  @vddk              = nil

  def self.server(server)
    return unless @vddk.nil?
    @vddk = server
  end

  @info_log  = ->(s) { logger.info "VMware(VixDiskLib): #{s}" }
  @warn_log  = ->(s) { logger.warn "VMware(VixDiskLib): #{s}" }
  @error_log = ->(s) { logger.error "VMware(VixDiskLib): #{s}" }

  def self.init
    return if @initialized
    FFI::VixDiskLib::ApiWrapper.init(@info_log, @warn_log, @error_log, nil)
    @initialized = true
    @connection = nil
  end

  def self.dumpDisks(server_name)
    logger.warn "*** Open VdlDisks for server #{server_name}"
    @connection.dumpDisks unless @connection.nil? || @connection.serverName != server_name
    @vddk.running = true
    logger.warn "*** Open VdlDisks end"
  end

  def self.inc_server_disk_count
    @server_disk_count += 1
    @vddk.running = true
    @server_disk_count
  end

  def self.dec_server_disk_count
    @server_disk_count -= 1
    @vddk.running = true
    @server_disk_count
  end

  def self.connect(connect_parms)
    logger.info "VdlWrapper.connect: #{connect_parms[:server_name]}"
    raise VixDiskLibError, "VixDiskLib is not initialized" unless @initialized
    raise VixDiskLibError, "Already connected to #{@connection.serverName}" if @connection
    @connection = VdlConnection.new(connect_parms, @vddk)
    @connection
  end

  def self.__disconnect__(conn_obj)
    logger.info "VdlWrapper.__disconnect__: #{conn_obj.serverName}"
    raise VixDiskLibError, "VixDiskLib is not initialized" unless @initialized
    FFI::VixDiskLib::API.disconnect(conn_obj.vdl_connection)
    @connection = nil
  end

  def self.__exit__
    raise VixDiskLibError, "VixDiskLib is not initialized" unless @initialized
    __disconnect__(@connection) unless @connection.nil?
    #
    # NOTE: We have to comment this call out for now.
    # For some reason the call to VixDiskLib.exit is causing
    # the DRb service (this process) to segfault during the exit sequence.
    #
    # super
    logger.info "VixDiskLib has exited cleanly"
    @vddk.running = true
    @vddk.shutdown = true
    @initialized = nil
  end
end # class VixDiskLib

class VdlConnection
  include DRb::DRbUndumped

  attr_reader :vdl_connection, :serverName, :vddk

  MAX_DISK_WARN = 9

  def initialize(connect_parms, vddk)
    @serverName     = connect_parms[:server_name]
    logger.info "VdlConnection.initialize: #{@serverName}"
    @vdl_connection  = VixDiskLibApi.connect(connect_parms)
    @disks           = []
    @disk_lock       = Sync.new
    @vddk            = vddk
  end

  def disconnect
    logger.info "VdlConnection.disconnect: #{@serverName}"
    @disk_lock.synchronize(:EX) do
      if !@vdl_connection
        logger.warn "VDLConnection.disconnect: server: #{@serverName} not connected"
      else
        __close_disks__
        VdlWrapper.__disconnect__(self)
        @vdl_connection = nil
        @vddk.running = true
        @vddk.shutdown = true
      end
    end
  end

  def dumpDisks
    raise VixDiskLibError, "VdlConnection.getDisk: server #{@serverName} not connected" unless @vdl_connection
    @vddk.running = true
    @disk_lock.sync_lock(:SH) if (unlock = !@disk_lock.sync_locked?)
    @disks.each do |d|
      logger.warn "    VdlDisk: #{d.path}, opened: #{d.timeStamp}"
    end
  ensure
    @disk_lock.sync_unlock if unlock
  end

  def getDisk(path, flags)
    @disk_lock.synchronize(:EX) do
      raise VixDiskLibError, "VdlConnection.getDisk: server #{@serverName} not connected" unless @vdl_connection
      @vddk.running = true
      disk = VdlDisk.new(self, path, flags)
      @disks << disk
      nd = VdlWrapper.inc_server_disk_count
      logger.info "VdlConnection.getDisk: #{@serverName} open disks = #{nd}"
      if nd >= MAX_DISK_WARN
        logger.warn "VdlConnection::getDisk: connection to server: #{@serverName}"
        logger.warn "VdlConnection::getDisk: number of open disks = #{nd}"
        logger.warn "VdlConnection::getDisk: subsequent open calls may fail"
        VdlWrapper.dumpDisks(@serverName)
      end
      return disk
    end
  end

  def __close_disk__(diskObj)
    @disk_lock.sync_lock(:EX) if (unlock = !@disk_lock.sync_exclusive?)

    @vddk.running = true
    VixDiskLibApi.close(diskObj.handle)
    if !@vdl_connection
      logger.warn "VDLConnection.disconnect: server: #{@serverName} not connected"
    else
      @disks.delete(diskObj)
      nd = VdlWrapper.dec_server_disk_count
      logger.warn "VdlConnection.__close_disk__: #{@serverName} open disks = #{nd}"
    end
  ensure
    @disk_lock.sync_unlock if unlock
  end

  def __close_disks__
    raise VixDiskLibError,
          "VdlConnection::__close_disks__: exclusive disk lock not held" unless @disk_lock.sync_exclusive?
    if !@vdl_connection
      logger.warn "VDLConnection.disconnect: server: #{@serverName} not connected"
    else
      @disks.each(&:close)
    end
  end
  private :__close_disks__
end # class VdlConnection

class VdlDisk
  include DRb::DRbUndumped
  include VMwareWebService::Logging

  attr_reader :path, :flags, :handle, :sectorSize, :timeStamp, :info

  MIN_SECTORS_TO_CACHE = 64

  def initialize(conn_obj, path, flags)
    @time_stamp = Time.now
    logger.debug { "VdlDisk.new <#{object_id}>: opening #{path}" }
    @connection = conn_obj
    @handle = VixDiskLibApi.open(@connection.vdl_connection, path, flags)
    @path = path
    @flags = flags
    @sectorSize = FFI::VixDiskLib::API::VIXDISKLIB_SECTOR_SIZE
    @info = VixDiskLibApi.get_info(@handle)
    @handle_lock = Sync.new
    @cache = @cache_range = nil

    @num_sectors = @info[:capacity]
    @num_bytes   = @num_sectors * @sectorSize
    @vddk        = conn_obj.vddk
  end

  def close
    logger.debug { "VdlDisk.close <#{ssId}>: closing #{@path}" }
    @vddk.running = true
    @handle_lock.synchronize(:EX) do
      if !@handle
        logger.debug { "VdlDisk.close: #{@path} not open" }
      else
        @connection.__close_disk__(self)
        @handle = nil
        @cache      = nil
        @cache_range = nil
      end
    end
  end

  def bread(start_sector, num_sectors)
    @vddk.running = true
    @handle_lock.sync_lock(:SH) if (unlock = !@handle_lock.sync_locked?)

    raise VixDiskLibError, "VdlDisk.bread: disk is not open" unless @handle
    return nil if start_sector >= @num_sectors
    num_sectors = @num_sectors - start_sector if (start_sector + num_sectors) > @num_sectors

    return VixDiskLibApi.read(@handle, start_sector, num_sectors)
  ensure
    @handle_lock.sync_unlock if unlock
  end

  def bwrite(start_sector, num_sectors, buf)
    @vddk.running = true
    @handle_lock.sync_lock(:SH) if (unlock = !@handle_lock.sync_locked?)

    raise VixDiskLibError, "VdlDisk.bwrite: disk is not open" unless @handle
    return nil if start_sector >= @num_sectors
    num_sectors = @num_sectors - start_sector if (start_sector + num_sectors) > @num_sectors

    VixDiskLibApi.write(@handle, start_sector, num_sectors, buf)
    return num_sectors
  ensure
    @handle_lock.sync_unlock if unlock
  end

  def breadCached(start_sector, num_sectors)
    @vddk.running = true
    if @cache_range.nil? ||
       !@cache_range.include?(start_sector) ||
       !@cache_range.include?(start_sector + num_sectors - 1)
      sectors_to_read = [MIN_SECTORS_TO_CACHE, num_sectors].max
      @cache        = bread(start_sector, sectors_to_read)
      sectors_read   = @cache.length / @sectorSize
      end_sector     = start_sector + sectors_read - 1
      @cache_range   = Range.new(start_sector, end_sector)
    end

    sector_offset = start_sector - @cache_range.first
    buffer_offset = sector_offset * @sectorSize
    length       = num_sectors * @sectorSize

    @cache[buffer_offset, length]
  end

  def read(pos, len)
    @vddk.running = true
    @handle_lock.synchronize(:SH) do
      raise VixDiskLibError, "VdlDisk.read: disk is not open" unless @handle

      return nil if pos >= @num_bytes
      len = @num_bytes - pos if (pos + len) > @num_bytes

      start_sector, start_offset = pos.divmod(@sectorSize)
      end_sector = (pos + len - 1) / @sectorSize
      num_sector = end_sector - start_sector + 1

      r_buf = breadCached(start_sector, num_sector)
      return r_buf[start_offset, len]
    end
  end

  def write(pos, buf, len)
    @vddk.running = true
    @handle_lock.synchronize(:SH) do
      raise VixDiskLibError, "VdlDisk.write: disk is not open" unless @handle

      return nil if pos >= @num_bytes
      len = @num_bytes - pos if (pos + len) > @num_bytes

      start_sector, start_offset = pos.divmod(@sectorSize)
      end_sector = (pos + len - 1) / @sectorSize
      num_sector = end_sector - start_sector + 1
      r_buf = bread(start_sector, num_sector)
      r_buf[start_offset, len] = buf[0, len]
      bwrite(start_sector, num_sector, r_buf)
      return len
    end
  end

  def ssId
    object_id
  end
end # class VdlDisk
