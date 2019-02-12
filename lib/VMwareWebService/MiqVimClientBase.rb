require 'pathname'

require 'sync'
require 'VMwareWebService/VimService'

# require 'profile'

class MiqVimClientBase < VimService
  attr_reader :server, :username, :password, :connId

  def initialize(server, username, password)
    @server   = server
    @username = username
    @password = password
    @connId   = "#{@server}_#{@username}"

    super(server)

    @connected  = false
    @connLock = Sync.new
  end

  def connect
    $vim_log.debug "#{self.class.name}.connect(#{@connId}): #{$PROGRAM_NAME} #{ARGV.join(' ')}" if $vim_log.debug?
    @connLock.synchronize(:EX) do
      return if @connected
      login(@sic.sessionManager, @username, @password)
      @connected = true
    end
  end

  def disconnect
    $vim_log.debug "#{self.class.name}.disconnect(#{@connId}): #{$PROGRAM_NAME} #{ARGV.join(' ')}" if $vim_log.debug?
    @connLock.synchronize(:EX) do
      return unless @connected
      logout(@sic.sessionManager)
      @connected = false
    end
  end

  def currentServerTime
    DateTime.parse(currentTime)
  end

  def acquireCloneTicket
    super(@sic.sessionManager)
  end

  def verify_callback(is_ok, ctx)
    if $DEBUG
      puts "#{is_ok ? 'ok' : 'ng'}: #{ctx.current_cert.subject}"
    end
    unless is_ok
      depth = ctx.error_depth
      code = ctx.error
      msg = ctx.error_string
      STDERR.puts "at depth #{depth} - #{code}: #{msg}" if $DEBUG
    end
    is_ok
  end

  private

  def prop_set_to_hash(hash, prop_set)
    prop_set.each do |dynamic_property|
      val = dynamic_property_to_hash(dynamic_property.val)
      h, k = hashTarget(hash, dynamic_property.name)
      if !h[k]
        h[k] = val
      elsif h[k].kind_of?(Array)
        h[k] << val
      else
        h[k] = VimArray.new do |arr|
          arr << h[k]
          arr << val
        end
      end
    end
  end

  def dynamic_property_to_hash(val)
    case val
    when Array
      val.map { |v| dynamic_property_to_hash(v) }
    when RbVmomi::VIM::DataObject
      val.props.each_with_object(VimHash.new(val.class.wsdl_name)) do |(k, v), hash|
        hash[k.to_s] = dynamic_property_to_hash(v)
      end
    else
      val
    end
  end
end # class MiqVimClientBase
