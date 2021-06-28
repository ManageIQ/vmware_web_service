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
  def initialize(server, username, password, cacheScope = nil, monitor_updates = nil, preLoad = nil, debugUpdates = false, notifyMethod = nil, maxWait = 60, maxObjects = 250)
    super(server, username, password, cacheScope)

    monitor_updates = self.class.monitor_updates if monitor_updates.nil?
    preLoad         = self.class.pre_load        if preLoad.nil?

    @monitor_updates    = monitor_updates
    @updateMonitorReady = false
    @error              = nil
    @notifyMethod       = notifyMethod
    @debugUpdates       = debugUpdates
    @maxWait            = maxWait
    @maxObjects         = maxObjects

    start_monitor_updates_thread(preLoad) if @monitor_updates
  end

  @@monitor_updates = false
  @@pre_load        = false

  def self.monitor_updates
    @@monitor_updates
  end

  def self.monitor_updates=(val)
    @@monitor_updates = val
  end

  def self.pre_load
    @@pre_load
  end

  def self.pre_load=(val)
    @@pre_load = val
  end

  def getVimVm(path)
    logger.info "MiqVimMod.getVimVm: called"
    miqVimVm = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find VM: #{path}" unless (vmh = virtualMachines_locked[path])
      miqVimVm = MiqVimVm.new(self, conditionalCopy(vmh))
    end
    logger.info "MiqVimMod.getVimVm: returning object #{miqVimVm.object_id}"
    (miqVimVm)
  end # def getVimVm

  def getVimVmByMor(vmMor)
    logger.info "MiqVimMod.getVimVmByMor: called"
    miqVimVm = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find VM: #{vmMor}" unless (vmh = virtualMachinesByMor_locked[vmMor])
      miqVimVm = MiqVimVm.new(self, conditionalCopy(vmh))
    end
    logger.info "MiqVimMod.getVimVmByMor: returning object #{miqVimVm.object_id}"
    (miqVimVm)
  end # def getVimVmByMor

  #
  # Returns a MiqVimVm object for the first VM found that
  # matches the criteria defined by the filter.
  #
  def getVimVmByFilter(filter)
    logger.info "MiqVimMod.getVimVmByFilter: called"
    miqVimVm = nil
    @cacheLock.synchronize(:SH) do
      vms = applyFilter(virtualMachinesByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimVmByFilter: Could not find VM matching filter" if vms.empty?
      miqVimVm = MiqVimVm.new(self, conditionalCopy(vms[0]))
    end
    logger.info "MiqVimMod.getVimVmByFilter: returning object #{miqVimVm.object_id}"
    (miqVimVm)
  end # def getVimVmByFilter

  def getVimHost(name)
    logger.info "MiqVimMod.getVimHost: called"
    miqVimHost = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Host: #{name}" unless (hh = hostSystems_locked[name])
      miqVimHost = MiqVimHost.new(self, conditionalCopy(hh))
    end
    logger.info "MiqVimMod.getVimHost: returning object #{miqVimHost.object_id}"
    (miqVimHost)
  end # def getVimHost

  def getVimHostByMor(hMor)
    logger.info "MiqVimMod.getVimHostByMor: called"
    miqVimHost = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Host: #{hMor}" unless (hh = hostSystemsByMor_locked[hMor])
      miqVimHost = MiqVimHost.new(self, conditionalCopy(hh))
    end
    logger.info "MiqVimMod.getVimHostByMor: returning object #{miqVimHost.object_id}"
    (miqVimHost)
  end # def getVimHostByMor

  #
  # Returns a MiqVimHost object for the first Host found that
  # matches the criteria defined by the filter.
  #
  def getVimHostByFilter(filter)
    logger.info "MiqVimMod.getVimHostByFilter: called"
    miqVimHost = nil
    @cacheLock.synchronize(:SH) do
      ha = applyFilter(hostSystemsByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimHostByFilter: Could not find Host matching filter" if ha.empty?
      miqVimHost = MiqVimHost.new(self, conditionalCopy(ha[0]))
    end
    logger.info "MiqVimMod.getVimHostByFilter: returning object #{miqVimHost.object_id}"
    (miqVimHost)
  end # def getVimHostByFilter

  def getVimFolder(name)
    logger.info "MiqVimMod.getVimFolder: called"
    miqVimFolder = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Folder: #{name}" unless (fh = folders_locked[name])
      miqVimFolder = MiqVimFolder.new(self, conditionalCopy(fh))
    end
    logger.info "MiqVimMod.getVimFolder: returning object #{miqVimFolder.object_id}"
    (miqVimFolder)
  end # def getVimFolder

  def getVimFolderByMor(fMor)
    logger.info "MiqVimMod.getVimFolderByMor: called"
    miqVimFolder = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Folder: #{fMor}" unless (fh = foldersByMor_locked[fMor])
      miqVimFolder = MiqVimFolder.new(self, conditionalCopy(fh))
    end
    logger.info "MiqVimMod.getVimFolderByMor: returning object #{miqVimFolder.object_id}"
    (miqVimFolder)
  end # def getVimFolderByMor

  def getVimFolderByFilter(filter)
    logger.info "MiqVimMod.getVimFolderByFilter: called"
    miqVimFolder = nil
    @cacheLock.synchronize(:SH) do
      folders = applyFilter(foldersByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimFolderByFilter: Could not find folder matching filter" if folders.empty?
      miqVimFolder = MiqVimFolder.new(self, conditionalCopy(folders[0]))
    end
    logger.info "MiqVimMod.getVimFolderByFilter: returning object #{miqVimFolder.object_id}"
    (miqVimFolder)
  end # def getVimFolderByFilter

  #
  # Cluster
  #
  def getVimCluster(name)
    logger.info "MiqVimMod.getVimCluster: called"
    miqVimCluster = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Cluster: #{name}" unless (ch = clusterComputeResources_locked[name])
      miqVimCluster = MiqVimCluster.new(self, conditionalCopy(ch))
    end
    logger.info "MiqVimMod.getVimCluster: returning object #{miqVimCluster.object_id}"
    (miqVimCluster)
  end # def getVimCluster

  def getVimClusterByMor(cMor)
    logger.info "MiqVimMod.getVimClusterByMor: called"
    miqVimCluster = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find Cluster: #{cMor}" unless (ch = clusterComputeResourcesByMor_locked[cMor])
      miqVimCluster = MiqVimCluster.new(self, conditionalCopy(ch))
    end
    logger.info "MiqVimMod.getVimClusterByMor: returning object #{miqVimCluster.object_id}"
    (miqVimCluster)
  end # def getVimClusterByMor

  def getVimClusterByFilter(filter)
    logger.info "MiqVimMod.getVimClusterByFilter: called"
    miqVimCluster = nil
    @cacheLock.synchronize(:SH) do
      clusters = applyFilter(clusterComputeResourcesByMor_locked.values, filter)
      raise MiqException::MiqVimResourceNotFound, "getVimClusterByFilter: Could not find Cluster matching filter" if clusters.empty?
      miqVimCluster = MiqVimCluster.new(self, conditionalCopy(clusters[0]))
    end
    logger.info "MiqVimMod.getVimClusterByFilter: returning object #{miqVimCluster.object_id}"
    (miqVimCluster)
  end # def getVimClusterByFilter

  #
  # DataStore
  #
  def getVimDataStore(dsName)
    logger.info "MiqVimMod.getVimDataStore: called"
    miqVimDs = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find datastore: #{dsName}" unless (dsh = dataStores_locked[dsName])
      miqVimDs = MiqVimDataStore.new(self, conditionalCopy(dsh))
    end
    logger.info "MiqVimMod.getVimDataStore: returning object #{miqVimDs.object_id}"
    (miqVimDs)
  end

  def getVimDataStoreByMor(dsMor)
    logger.info "MiqVimMod.getVimDataStoreByMor: called"
    miqVimDs = nil
    @cacheLock.synchronize(:SH) do
      raise MiqException::MiqVimResourceNotFound, "Could not find datastore: #{dsMor}" unless (dsh = dataStoresByMor_locked[dsMor])
      miqVimDs = MiqVimDataStore.new(self, conditionalCopy(dsh))
    end
    logger.info "MiqVimMod.getVimDataStoreByMor: returning object #{miqVimDs.object_id}"
    (miqVimDs)
  end

  def getVimPerfHistory
    miqVimPh = MiqVimPerfHistory.new(self)
    logger.info "MiqVimMod.getVimPerfHistory: returning object #{miqVimPh.object_id}"
    (miqVimPh)
  end

  def getVimEventHistory(eventFilterSpec = nil, pgSize = 20)
    miqVimEh = MiqVimEventHistoryCollector.new(self, eventFilterSpec, pgSize)
    logger.info "MiqVimMod.getVimEventHistory: returning object #{miqVimEh.object_id}"
    (miqVimEh)
  end

  def getMiqCustomFieldsManager
    miqVimCfm = MiqCustomFieldsManager.new(self)
    logger.info "MiqVimMod.getMiqCustomFieldsManager: returning object #{miqVimCfm.object_id}"
    (miqVimCfm)
  end

  def getVimAlarmManager
    miqVimAm = MiqVimAlarmManager.new(self)
    logger.info "MiqVimMod.getVimAlarmManager: returning object #{miqVimAm.object_id}"
    (miqVimAm)
  end

  def getVimCustomizationSpecManager
    miqVimCsm = MiqVimCustomizationSpecManager.new(self)
    logger.info "MiqVimMod.getVimCustomizationSpecManager: returning object #{miqVimCsm.object_id}"
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
    logger.info "#{log_prefix}: starting update monitor thread"
    @updateThread = Thread.new { monitor(preLoad) }
    @updateThread[:vim_connection_id] = connId
    logger.info "#{log_prefix}: waiting for update monitor to become ready"
    until @updateMonitorReady
      raise @error unless @error.nil?
      break unless @updateThread.alive?
      Thread.pass
    end
    logger.info "#{log_prefix}: update monitor ready"
  end

  def checkForOrphanedMonitors
    log_prefix = "MiqVim.checkForOrphanedMonitors (#{@connId})"
    logger.debug "#{log_prefix}: called..."
    Thread.list.each do |thr|
      next unless thr[:vim_connection_id] == connId
      logger.error "#{log_prefix}: Terminating orphaned update monitor <#{thr.object_id}>"
      thr.raise "Orphaned update monitor (#{@connId}) <#{thr.object_id}>, terminated by <#{Thread.current.object_id}>"
      thr.wakeup
    end
    logger.debug "#{log_prefix}: done."
  end

  def monitor(preLoad)
    log_prefix = "MiqVim.monitor (#{@connId})"
    begin
      monitorUpdates(preLoad)
    rescue Exception => err
      logger.info "#{log_prefix}: returned from monitorUpdates via #{err.class} exception"
      @error = err
    end
  end

  def shutdown_monitor_updates_thread
    log_prefix = "MiqVim.disconnect (#{@connId})"
    stopUpdateMonitor
    begin
      if @updateThread != Thread.current && @updateThread.alive?
        logger.info "#{log_prefix}: waiting for Update Monitor Thread...Starting"
        @updateThread.join
        logger.info "#{log_prefix}: waiting for Update Monitor Thread...Complete"
      end
    rescue
    end
  end
end # module MiqVim
