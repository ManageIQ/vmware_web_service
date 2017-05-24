require 'manageiq-gems-pending'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

$vim_log = Logger.new(STDOUT)
$vim_log.level = Logger::WARN

# $miq_wiredump = true

# TARGET_HOST = "vi4esxm1.manageiq.com"
TARGET_HOST = raise "please define"
VNIC_DEV  = "vmk1"
hMor = nil

broker = MiqVimBroker.new(:client)
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    puts "Host name: #{TARGET_HOST}"
    puts
  
    miqHost = vim.getVimHost(TARGET_HOST)

    puts "Host name: #{miqHost.name}"
    puts
  
    vnm = miqHost.hostVirtualNicManager
  
    puts "**** hostVirtualNicManager.info:"
    vim.dumpObj(vnm.info)
    puts "**** END hostVirtualNicManager.info"
    puts
  
    cVnics = vnm.candidateVnicsByType("vmotion")
  
    puts "**** Candidate vnics for vmotion:"
    cVnics.each do |vmn|
      puts "Device: #{vmn.device}, Key: #{vmn.key}"
    end
    puts "**** END Candidate vnics for vmotion"
    puts
  
    selVna = vnm.selectedVnicsByType("vmotion")
  
    puts "**** Selected vnics for vmotion:"
    selVna.each do |vnn|
      puts "Key: #{vnn}"
    end
    puts "**** END Selected vnics for vmotion"
    puts
  
    # svn = selVna.first
    # svd = nil
    # cVnics.each do |cvn|
    #   if cvn.key == svn
    #     svd = cvn.device
    #     break
    #   end
    # end
    # 
    # puts "**** Deselecting: #{svd}..."
    # vnm.deselectVnicForNicType("vmotion", svd)
    # puts "**** Done."
    # puts
  
    puts "**** Selecting: #{VNIC_DEV}..."
    vnm.selectVnicForNicType("vmotion", VNIC_DEV)
    puts "**** Done."
    puts
  
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end
