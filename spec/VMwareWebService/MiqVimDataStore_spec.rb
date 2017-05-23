require 'VMwareWebService/MiqVim'

describe MiqVimDataStore do
  context "#encode_datastore_url" do
    before do
      @invObj = double
      allow(@invObj).to receive(:server).and_return('192.168.1.2')
      allow(@invObj).to receive(:sic).and_return(nil)
      allow(@invObj).to receive(:apiVersion).and_return('5.5.0')

      dsh = {
        'summary' => {
          'name' => 'datastore1'
        }
      }

      @vimDs = MiqVimDataStore.new(@invObj, dsh)
    end

    it 'with a simple vm path' do
      url = subject('vm1')
      expect(url).to eq("https://192.168.1.2/folder/vm1%2Fvm1.vmsd?dsName=datastore1")
    end

    it 'with a vm with special characters' do
      url = subject('vm [ ] ( ) *&#$@!^-_+')
      expect(url).to eq("https://192.168.1.2/folder/vm%20%5B%20%5D%20(%20)%20*%26%23%24%40!%5E-_%2B%2Fvm%20%5B%20%5D%20(%20)%20*%26%23%24%40!%5E-_%2B.vmsd?dsName=datastore1")
    end

    private

    def subject(vmname)
      filepath = snapshotfile(vmname)
      @vimDs.send(:encode_datastore_url, filepath, @vimDs.name)
    end

    def snapshotfile(vmname)
      File.join(vmname, "#{vmname}.vmsd")
    end
  end
end
