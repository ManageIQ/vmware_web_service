module VMwareWebService
  class << self
    attr_writer :logger
  end

  def self.logger
    require "logger"
    @logger ||= Logger.new(nil)
  end

  module Logging
    def logger
      VMwareWebService.logger
    end
  end
end
