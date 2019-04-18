lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'VMwareWebService/version'

Gem::Specification.new do |spec|
  spec.name        = "vmware_web_service"
  spec.version     = VMwareWebService::VERSION
  spec.authors     = ["ManageIQ Developers"]
  spec.homepage    = "https://github.com/ManageIQ/vmware_web_service"
  spec.summary     = "A ruby interface to Vmware Web Services SDK"
  spec.description = "A ruby interface to Vmware Web Services SDK"
  spec.licenses    = ["Apache-2.0"]

  spec.files = Dir["{app,config,lib}/**/*"]

  spec.add_dependency "activesupport",        ">= 5.0", "< 5.2"
  spec.add_dependency "ffi",                  "~>1.9.3"
  spec.add_dependency "ffi-vix_disk_lib",     "~>1.0.5"  # used by VixDiskLib
  spec.add_dependency "handsoap",             "~>0.2.5"
  spec.add_dependency "httpclient",           "~>2.8.0"
  spec.add_dependency "more_core_extensions", "~>3.2"
  spec.add_dependency "rbvmomi",              "~>2.1.0"

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 1.0.0'
  spec.add_development_dependency 'manageiq-password'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.52'
  spec.add_development_dependency 'simplecov'
end
