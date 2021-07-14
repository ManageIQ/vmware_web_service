require 'pathname'

require 'sync'
require 'VMwareWebService/VimService'

# require 'profile'

class MiqVimClientBase < VimService
  @@receiveTimeout = 120

  attr_reader :server, :port, :username, :password, :connId

  def initialize(server:, username:, password:, port: 443, ssl_options: {})
    @server   = server
    @port     = port
    @username = username
    @password = password
    @connId   = "#{@server}_#{@username}"

    @receiveTimeout = @@receiveTimeout

    on_http_client_init do |http_client, _headers|
      http_client.receive_timeout        = @receiveTimeout
      http_client.ssl_config.verify_mode = ssl_options[:verify_ssl] || OpenSSL::SSL::VERIFY_NONE
      http_client.ssl_config.cert_store.add_cert(OpenSSL::X509::Certificate.new(ssl_options[:ca_file])) if ssl_options[:ca_file]
    end

    on_log_header { |msg| logger.info msg }
    on_log_body   { |msg| logger.debug msg } if $miq_wiredump

    super(:uri => sdk_uri, :version => 1)

    @connected  = false
    @connLock = Sync.new
  end

  def sdk_uri
    URI::HTTPS.build(:host => server, :port => port, :path => "/sdk")
  end

  def self.receiveTimeout=(val)
    @@receiveTimeout = val
  end

  def self.receiveTimeout
    @@receiveTimeout
  end

  def receiveTimeout=(val)
    @connLock.synchronize(:EX) do
      @receiveTimeout = val
      http_client.receive_timeout = @receiveTimeout if http_client
    end
  end

  def receiveTimeout
    @connLock.synchronize(:SH) do
      @receiveTimeout
    end
  end

  def connect
    logger.debug { "#{self.class.name}.connect(#{@connId}): #{$PROGRAM_NAME} #{ARGV.join(' ')}" }
    @connLock.synchronize(:EX) do
      return if @connected
      login(@sic.sessionManager, @username, @password)
      @connected = true
    end
  end

  def disconnect
    logger.debug { "#{self.class.name}.disconnect(#{@connId}): #{$PROGRAM_NAME} #{ARGV.join(' ')}" }
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
end # class MiqVimClientBase
