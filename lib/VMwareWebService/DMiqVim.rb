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

  def initialize(server, username, password, broker, preLoad = false, debugUpdates = false, notifyMethod = nil, cacheScope = nil, maxWait = 60, maxObjects = 250)
    super(server, username, password, cacheScope, true, preLoad, debugUpdates, notifyMethod, maxWait, maxObjects)

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
