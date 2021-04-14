require "logger"

module VMwareWebService
  class << self
    attr_writter :logger
  end

  def self.logger
    @logger ||= Logger.new(nil)
  end

  module Logging
    def logger
      VMwareWebService.logger
    end
  end
end
