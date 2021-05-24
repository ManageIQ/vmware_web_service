require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'

VMwareWebService.logger = Logger.new(STDOUT)
VMwareWebService.logger.level = Logger::WARN

TARGET_VM = "rpo-template-test"
vmMor = nil
miqVm = nil

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"
  puts

  miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  puts "VM: #{miqVm.name}"
  puts

  isTemplate = miqVm.template?

  puts "Template: #{isTemplate}"
  unless isTemplate
    puts "Marking VM as Template."
    miqVm.markAsTemplate
    puts "Template: #{miqVm.template?}"
    exit
  end

  targetHostObj = vim.hostSystems.values.first
  raise "No suitable target host system found" unless targetHostObj

  targetRp = nil
  vim.resourcePoolsByMor.each_value do |rp|
    owner = rp['owner']
    next unless (cr = vim.computeResourcesByMor[owner])
    hosts = cr['host']['ManagedObjectReference']
    hosts = [hosts] unless hosts.kind_of?(Array)
    hosts.each do |hmor|
      if hmor == targetHostObj['MOR']
        targetRp = rp
        break
      end
    end
    break if targetRp
  end
  puts

  raise "No suitable target resource pool found" unless targetRp

  puts "Marking VM as Virtual Machine."
  puts
  miqVm.markAsVm(targetRp, targetHostObj)
  puts "Template: #{miqVm.template?}"
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  puts
  puts "Exiting..."
  miqVm.release if miqVm
  vim.disconnect if vim
end
