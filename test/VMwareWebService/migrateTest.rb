require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

TARGET_VM = "rpo-test2"
vmMor = nil
miqVm = nil

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
  
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts
  
  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
  
  puts "VM: #{miqVm.name}, HOST: #{miqVm.hostSystem}"
  puts
  
  targetHostName = nil
  targetHostObj  = nil
  puts "Host systems:"
  vim.hostSystems.each do |k, v|
      if k != miqVm.hostSystem
          targetHostName = k
          targetHostObj = v
      end
      puts "\t#{k} (#{v['MOR']})"
  end
  puts
  
  raise "No suitable target host system found" if !targetHostName
  
  targetRp = nil
  vim.resourcePoolsByMor.each_value do |rp|
      owner = rp['owner']
      next if !(cr = vim.computeResourcesByMor[owner])
      hosts = cr['host']['ManagedObjectReference']
      hosts = [ hosts ] if !hosts.kind_of?(Array)
      hosts.each do |hmor|
          if hmor == targetHostObj['MOR']
              targetRp = rp
              break
          end
      end
      break if targetRp
  end
  puts
  
  raise "No suitable target resource pool found" if !targetRp
  
  puts "Migrating #{miqVm.name} from #{miqVm.hostSystem} to #{targetHostName}"
  puts
  miqVm.migrate(targetHostObj, targetRp)
  
  miqVm.refresh
  puts "VM: #{miqVm.name}, HOST: #{miqVm.hostSystem}"
  puts
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  miqVm.release if miqVm
  vim.disconnect if vim
end
