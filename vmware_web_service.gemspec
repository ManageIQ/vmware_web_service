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

  spec.required_ruby_version = ">= 2.6.0"
  spec.files = Dir["{app,config,lib}/**/*"]

  spec.add_dependency "ffi-vix_disk_lib",     "~>1.1"
  spec.add_dependency "handsoap",             "~>0.2.5"
  spec.add_dependency "httpclient",           "~>2.8.0"
  spec.add_dependency "more_core_extensions", ">= 3.2", "< 5"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec",          "~> 3.0"
  spec.add_development_dependency "simplecov",      ">= 0.21.2"
end
