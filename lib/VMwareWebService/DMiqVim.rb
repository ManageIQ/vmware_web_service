require 'VMwareWebService/MiqVim'
require 'VMwareWebService/DMiqVimSync'

#
# Class used to wrap locked object and return it through DRB.
#
class MiqDrbReturn
  attr_accessor :obj, :lock

  def initialize(obj, lock = nil)
    @obj = obj
    @lock = lock
  end
end

class DMiqVim < MiqVim
  alias_method :serverPrivateConnect, :connect
  alias_method :serverPrivateDisconnect, :disconnect
  alias_method :conditionalCopy, :deepClone

  include DRb::DRbUndumped
  include DMiqVimSync

  # @param server [String] DNS name or IP address of the vCenter Server 
  # @param username [String] Username to connect to the vCenter Server
  # @param password [String] Password to connect to the vCenter Server
  # @param broker [MiqVimBroker] Instance of the broker worker this connection belongs to
  # @param preLoad [Bool] Should the cache be built before returning the connection (default: false)
  # @param debugUpdates [Bool] Should we print debug info for each update (default: false)
  # @param notifyMethod [Method] A optional method to call for each update (default: nil)
  # @param cacheScope [Symbol] A pre-defined set of properties to cache (default: nil)
  # @param maxWait [Integer] How many seconds to wait before breaking out of WaitForUpdates (default: 60)
  # @param maxObjects [Integer] How many objects to return from each WaitForUpdates page (default: 250)
  def initialize(server, username, password, broker, preLoad = false, debugUpdates = false, notifyMethod = nil, cacheScope = nil, maxWait = 60, maxObjects = 250)
    super(server, username, password, cacheScope, monitor_updates = true, preLoad, debugUpdates, notifyMethod, maxWait, maxObjects)

    @broker                 = broker
    @connectionShuttingDown = false
    @connectionRemoved      = false
  end

  def monitor(preLoad)
    log_prefix = "DMiqVim.monitor (#{@connId})"
    begin
      monitorUpdates(preLoad)
    rescue Exception => err
      # if handleSessionNotAuthenticated(err)
      #   $vim_log.info "#{log_prefix}: Restarting Update Monitor" if $vim_log
      #   retry
      # end
      $vim_log.info "#{log_prefix}: returned from monitorUpdates via #{err.class} exception" if $vim_log
      @error = err
    ensure
      $vim_log.info "#{log_prefix}: returned from monitorUpdates" if $vim_log
      if @updateMonitorReady && !@broker.shuttingDown
        @broker.connTrySync(:EX, server, username) do |key|
          @broker.removeMiqVimSS(key, self)
        end

        if @notifyMethod
          @notifyMethod.call(:server   => @server,
                             :username => @username,
                             :op       => 'MiqVimRemoved',
                             :error    => @error
                            )
        end
      end
    end
  end

  def shutdownConnection
    return if @connectionShuttingDown
    log_prefix = "DMiqVim.shutdownConnection (#{@connId})"
    $vim_log.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Starting" if $vim_log
    @connectionShuttingDown = true
    serverPrivateDisconnect if self.isAlive?
    $vim_log.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Complete" if $vim_log
  end

  def connectionRemoved?
    @connectionRemoved
  end

  def connectionRemoved
    @connectionRemoved = true
  end

  def connect
    (true)
  end

  def disconnect
    (true)
  end
end # class DMiqVim
