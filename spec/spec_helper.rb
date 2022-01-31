if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

RSpec.configure do |config|
end

require "active_support"
puts
puts "\e[93mUsing ActiveSupport #{ActiveSupport.version}\e[0m"
