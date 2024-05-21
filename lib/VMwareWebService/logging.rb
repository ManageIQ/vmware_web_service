require "logger"

module VMwareWebService
  class << self
    attr_writer :logger
  end

  def self.logger
    require "logger"
    @logger ||= Logger.new(nil)
  end

  module Logging
    def self.included(other)
      other.extend(ClassMethods)
    end

    module ClassMethods
      def logger
        VMwareWebService.logger
      end
    end

    def logger
      self.class.logger
    end
  end
end
