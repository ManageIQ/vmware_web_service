require 'sync'

require 'VMwareWebService/MiqVimInventory'
require 'VMwareWebService/MiqVimVm'
require 'VMwareWebService/MiqVimVdlMod'
require 'VMwareWebService/MiqVimFolder'
require 'VMwareWebService/MiqVimCluster'
require 'VMwareWebService/MiqVimDataStore'
require 'VMwareWebService/MiqVimPerfHistory'
require 'VMwareWebService/MiqVimHost'
require 'VMwareWebService/MiqVimEventHistoryCollector'
require 'VMwareWebService/MiqCustomFieldsManager'
require 'VMwareWebService/MiqVimAlarmManager'
require 'VMwareWebService/MiqVimCustomizationSpecManager'
require 'VMwareWebService/MiqVimUpdate'

class MiqVim < MiqVimInventory
  include MiqVimVdlConnectionMod
  include MiqVimUpdate

  attr_reader :updateThread, :monitor_updates

  # @param server [String] DNS name or IP address of the vCenter Server 
  # @param username [String] Username to connect to the vCenter Server
  # @param password [String] Password to connect to the vCenter Server
  # @param cacheScope [Symbol] A pre-defined set of properties to cache (default: nil)
  # @param monitor_updates [Bool] Should a thread be started to monitor updates (default: false)
  # @param preLoad [Bool] Should the cache be built before returning the connection (default: false)
  # @param debugUpdates [Bool] Should we print debug info for each update (default: false)
  # @param notifyMethod [Method] A optional method to call for each update (default: nil)
  # @param maxWait [Integer] How many seconds to wait before breaking out of WaitForUpdates (default: 60)
  # @param maxObjects [Integer] How many objects to return from each WaitForUpdates page (default: 250)
  def initialize(server, username, password, cacheScope = nil, monitor_updates = false, preLoad = false, debugUpdates = false, notifyMethod = nil, maxWait = 60, maxObjects = 250)
    super(server, username, password, cacheScope)

    @monitor_updates    = monitor_updates
    @updateMonitorReady = false
    @error              = nil
    @notifyMethod       = notifyMethod
    @debugUpdates       = debugUpdates
    @maxWait            = maxWait
    @maxObjects         = maxObjects

    start_monitor_updates_thread(preLoad) if @monitor_updates
  end

  def getVimVm(path)
    $vim_log.info "MiqVimMod.getVimVm: called"
    miqVimVm = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find VM: #{path}" unless (vmh = virtualMachines_locked[path])
      miqVimVm = MiqVimVm.new(self, conditionalCopy(vmh))
    end
    $vim_log.info "MiqVimMod.getVimVm: returning object #{miqVimVm.object_id}"
    (miqVimVm)
  end # def getVimVm

  def getVimVmByMor(vmMor)
    $vim_log.info "MiqVimMod.getVimVmByMor: called"
    miqVimVm = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find VM: #{vmMor}" unless (vmh = virtualMachinesByMor_locked[vmMor])
      miqVimVm = MiqVimVm.new(self, conditionalCopy(vmh))
    end
    $vim_log.info "MiqVimMod.getVimVmByMor: returning object #{miqVimVm.object_id}"
    (miqVimVm)
  end # def getVimVmByMor

  #
  # Returns a MiqVimVm object for the first VM found that
  # matches the criteria defined by the filter.
  #
  def getVimVmByFilter(filter)
    $vim_log.info "MiqVimMod.getVimVmByFilter: called"
    miqVimVm = nil
    @cacheLock.synchronize(:SH) do
      vms = applyFilter(virtualMachinesByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimVmByFilter: Could not find VM matching filter" if vms.empty?
      miqVimVm = MiqVimVm.new(self, conditionalCopy(vms[0]))
    end
    $vim_log.info "MiqVimMod.getVimVmByFilter: returning object #{miqVimVm.object_id}"
    (miqVimVm)
  end # def getVimVmByFilter

  def getVimHost(name)
    $vim_log.info "MiqVimMod.getVimHost: called"
    miqVimHost = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Host: #{name}" unless (hh = hostSystems_locked[name])
      miqVimHost = MiqVimHost.new(self, conditionalCopy(hh))
    end
    $vim_log.info "MiqVimMod.getVimHost: returning object #{miqVimHost.object_id}"
    (miqVimHost)
  end # def getVimHost

  def getVimHostByMor(hMor)
    $vim_log.info "MiqVimMod.getVimHostByMor: called"
    miqVimHost = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Host: #{hMor}" unless (hh = hostSystemsByMor_locked[hMor])
      miqVimHost = MiqVimHost.new(self, conditionalCopy(hh))
    end
    $vim_log.info "MiqVimMod.getVimHostByMor: returning object #{miqVimHost.object_id}"
    (miqVimHost)
  end # def getVimHostByMor

  #
  # Returns a MiqVimHost object for the first Host found that
  # matches the criteria defined by the filter.
  #
  def getVimHostByFilter(filter)
    $vim_log.info "MiqVimMod.getVimHostByFilter: called"
    miqVimHost = nil
    @cacheLock.synchronize(:SH) do
      ha = applyFilter(hostSystemsByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimHostByFilter: Could not find Host matching filter" if ha.empty?
      miqVimHost = MiqVimHost.new(self, conditionalCopy(ha[0]))
    end
    $vim_log.info "MiqVimMod.getVimHostByFilter: returning object #{miqVimHost.object_id}"
    (miqVimHost)
  end # def getVimHostByFilter

  def getVimFolder(name)
    $vim_log.info "MiqVimMod.getVimFolder: called"
    miqVimFolder = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Folder: #{name}" unless (fh = folders_locked[name])
      miqVimFolder = MiqVimFolder.new(self, conditionalCopy(fh))
    end
    $vim_log.info "MiqVimMod.getVimFolder: returning object #{miqVimFolder.object_id}"
    (miqVimFolder)
  end # def getVimFolder

  def getVimFolderByMor(fMor)
    $vim_log.info "MiqVimMod.getVimFolderByMor: called"
    miqVimFolder = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Folder: #{fMor}" unless (fh = foldersByMor_locked[fMor])
      miqVimFolder = MiqVimFolder.new(self, conditionalCopy(fh))
    end
    $vim_log.info "MiqVimMod.getVimFolderByMor: returning object #{miqVimFolder.object_id}"
    (miqVimFolder)
  end # def getVimFolderByMor

  def getVimFolderByFilter(filter)
    $vim_log.info "MiqVimMod.getVimFolderByFilter: called"
    miqVimFolder = nil
    @cacheLock.synchronize(:SH) do
      folders = applyFilter(foldersByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimFolderByFilter: Could not find folder matching filter" if folders.empty?
      miqVimFolder = MiqVimFolder.new(self, conditionalCopy(folders[0]))
    end
    $vim_log.info "MiqVimMod.getVimFolderByFilter: returning object #{miqVimFolder.object_id}"
    (miqVimFolder)
  end # def getVimFolderByFilter

  #
  # Cluster
  #
  def getVimCluster(name)
    $vim_log.info "MiqVimMod.getVimCluster: called"
    miqVimCluster = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Cluster: #{name}" unless (ch = clusterComputeResources_locked[name])
      miqVimCluster = MiqVimCluster.new(self, conditionalCopy(ch))
    end
    $vim_log.info "MiqVimMod.getVimCluster: returning object #{miqVimCluster.object_id}"
    (miqVimCluster)
  end # def getVimCluster

  def getVimClusterByMor(cMor)
    $vim_log.info "MiqVimMod.getVimClusterByMor: called"
    miqVimCluster = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Cluster: #{cMor}" unless (ch = clusterComputeResourcesByMor_locked[cMor])
      miqVimCluster = MiqVimCluster.new(self, conditionalCopy(ch))
    end
    $vim_log.info "MiqVimMod.getVimClusterByMor: returning object #{miqVimCluster.object_id}"
    (miqVimCluster)
  end # def getVimClusterByMor

  def getVimClusterByFilter(filter)
    $vim_log.info "MiqVimMod.getVimClusterByFilter: called"
    miqVimCluster = nil
    @cacheLock.synchronize(:SH) do
      clusters = applyFilter(clusterComputeResourcesByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimClusterByFilter: Could not find Cluster matching filter" if clusters.empty?
      miqVimCluster = MiqVimCluster.new(self, conditionalCopy(clusters[0]))
    end
    $vim_log.info "MiqVimMod.getVimClusterByFilter: returning object #{miqVimCluster.object_id}"
    (miqVimCluster)
  end # def getVimClusterByFilter

  #
  # DataStore
  #
  def getVimDataStore(dsName)
    $vim_log.info "MiqVimMod.getVimDataStore: called"
    miqVimDs = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find datastore: #{dsName}" unless (dsh = dataStores_locked[dsName])
      miqVimDs = MiqVimDataStore.new(self, conditionalCopy(dsh))
    end
    $vim_log.info "MiqVimMod.getVimDataStore: returning object #{miqVimDs.object_id}"
    (miqVimDs)
  end

  def getVimDataStoreByMor(dsMor)
    $vim_log.info "MiqVimMod.getVimDataStoreByMor: called"
    miqVimDs = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find datastore: #{dsMor}" unless (dsh = dataStoresByMor_locked[dsMor])
      miqVimDs = MiqVimDataStore.new(self, conditionalCopy(dsh))
    end
    $vim_log.info "MiqVimMod.getVimDataStoreByMor: returning object #{miqVimDs.object_id}"
    (miqVimDs)
  end

  def getVimPerfHistory
    miqVimPh = MiqVimPerfHistory.new(self)
    $vim_log.info "MiqVimMod.getVimPerfHistory: returning object #{miqVimPh.object_id}"
    (miqVimPh)
  end

  def getVimEventHistory(eventFilterSpec = nil, pgSize = 20)
    miqVimEh = MiqVimEventHistoryCollector.new(self, eventFilterSpec, pgSize)
    $vim_log.info "MiqVimMod.getVimEventHistory: returning object #{miqVimEh.object_id}"
    (miqVimEh)
  end

  def getMiqCustomFieldsManager
    miqVimCfm = MiqCustomFieldsManager.new(self)
    $vim_log.info "MiqVimMod.getMiqCustomFieldsManager: returning object #{miqVimCfm.object_id}"
    (miqVimCfm)
  end

  def getVimAlarmManager
    miqVimAm = MiqVimAlarmManager.new(self)
    $vim_log.info "MiqVimMod.getVimAlarmManager: returning object #{miqVimAm.object_id}"
    (miqVimAm)
  end

  def getVimCustomizationSpecManager
    miqVimCsm = MiqVimCustomizationSpecManager.new(self)
    $vim_log.info "MiqVimMod.getVimCustomizationSpecManager: returning object #{miqVimCsm.object_id}"
    (miqVimCsm)
  end

  def disconnect
    shutdown_monitor_updates_thread if @monitor_updates

    super
  end

  private

  def start_monitor_updates_thread(preLoad)
    checkForOrphanedMonitors
    log_prefix          = "MiqVim.initialize (#{@connId})"
    $vim_log.info "#{log_prefix}: starting update monitor thread" if $vim_log
    @updateThread = Thread.new { monitor(preLoad) }
    @updateThread[:vim_connection_id] = connId
    $vim_log.info "#{log_prefix}: waiting for update monitor to become ready" if $vim_log
    until @updateMonitorReady
      raise @error unless @error.nil?
      break unless @updateThread.alive?
      Thread.pass
    end
    $vim_log.info "#{log_prefix}: update monitor ready" if $vim_log
  end

  def checkForOrphanedMonitors
    log_prefix = "MiqVim.checkForOrphanedMonitors (#{@connId})"
    $vim_log.debug "#{log_prefix}: called..."
    Thread.list.each do |thr|
      next unless thr[:vim_connection_id] == connId
      $vim_log.error "#{log_prefix}: Terminating orphaned update monitor <#{thr.object_id}>"
      thr.raise "Orphaned update monitor (#{@connId}) <#{thr.object_id}>, terminated by <#{Thread.current.object_id}>"
      thr.wakeup
    end
    $vim_log.debug "#{log_prefix}: done."
  end

  def monitor(preLoad)
    log_prefix = "MiqVim.monitor (#{@connId})"

    monitorUpdates(preLoad)
  rescue Exception => err
    $vim_log.info "#{log_prefix}: returned from monitorUpdates via #{err.class} exception" if $vim_log
    @error = err

    # If the monitorUpdates loop raised an exception but the underlying connection
    # is still alive then simply restart the monitorUpdates loop
    retry if isAlive?
  end

  def shutdown_monitor_updates_thread
    log_prefix = "MiqVim.disconnect (#{@connId})"
    stopUpdateMonitor
    begin
      if @updateThread != Thread.current && @updateThread.alive?
        $vim_log.info "#{log_prefix}: waiting for Update Monitor Thread...Starting" if $vim_log
        @updateThread.join
        $vim_log.info "#{log_prefix}: waiting for Update Monitor Thread...Complete" if $vim_log
      end
    rescue
    end
  end
end # module MiqVim
