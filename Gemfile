source 'https://rubygems.org'

plugin "bundler-inject", "~> 1.1"
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

# Specify your gem's dependencies in vmware_web_service.gemspec
gemspec

# Modified gems (forked on github)

gem "manageiq-gems-pending", ">0", :require => 'manageiq-gems-pending', :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"
gem "handsoap", "=0.2.5.5", :require => false, :source => "https://rubygems.manageiq.org"

minimum_version =
  case ENV['TEST_RAILS_VERSION']
  when "6.0"
    "~>6.0.4"
  when "7.0"
    "~>7.0.8"
  else
    "~>6.1.4"
  end

gem "activesupport", minimum_version
