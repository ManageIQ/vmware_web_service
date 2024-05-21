require 'VMwareWebService/logging'
require "tempfile"

describe VMwareWebService::Logging do
  subject do
    Class.new do
      include VMwareWebService::Logging
    end
  end

  before do
    @previous_logger, VMwareWebService.logger = VMwareWebService.instance_variable_get(:@logger), expected_logger
  end

  after do
    VMwareWebService.logger = @previous_logger
  end

  describe ".logger" do
    context "with no global logger set" do
      let(:expected_logger) { nil }

      it "returns the default global logger" do
        logger = subject.logger

        expect(logger).to be_a(Logger)
        expect(logger.instance_variable_get(:@logdev)).to be_nil
        expect(logger).to equal(VMwareWebService.logger)
      end
    end

    context "with a global logger set" do
      let(:logfile_name)    { Dir::Tmpname.create("test") {} }
      let(:expected_logger) { Logger.new(logfile_name) }

      it "returns the global logger" do
        logger = subject.logger

        expect(logger).to be_a Logger
        expect(logger.instance_variable_get(:@logdev).filename).to eq(logfile_name)
        expect(logger).to equal(VMwareWebService.logger)
      end
    end
  end

  describe "#logger" do
    context "with no global logger set" do
      let(:expected_logger) { nil }

      it "returns the default global logger" do
        logger = subject.new.logger

        expect(logger).to be_a(Logger)
        expect(logger.instance_variable_get(:@logdev)).to be_nil
        expect(logger).to equal(VMwareWebService.logger)
      end
    end

    context "with a global logger set" do
      let(:logfile_name)    { Dir::Tmpname.create("test") {} }
      let(:expected_logger) { Logger.new(logfile_name) }

      it "returns the global logger" do
        logger = subject.new.logger

        expect(logger).to be_a Logger
        expect(logger.instance_variable_get(:@logdev).filename).to eq(logfile_name)
        expect(logger).to equal(VMwareWebService.logger)
      end
    end
  end
end
