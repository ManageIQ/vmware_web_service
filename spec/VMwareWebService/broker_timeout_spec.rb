require 'timeout'
require 'VMwareWebService/broker_timeout'

describe Timeout do
  describe ".timeout" do
    it "doesn't fail when called without an error class" do
      Timeout.timeout(1) { }
    end
  end
end
