require "active_support"
require "active_support/concern"

module VMwareWebService
  class << self
    attr_writer :logger
  end

  def self.logger
    require "logger"
    @logger ||= Logger.new(nil)
  end

  module Logging
    extend ActiveSupport::Concern

    class_methods do
      def logger
        VMwareWebService.logger
      end
    end

    def logger
      self.class.logger
    end
  end
end
