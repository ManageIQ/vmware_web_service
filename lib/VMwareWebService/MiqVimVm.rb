require 'sync'

require "ostruct"

require 'more_core_extensions/core_ext/hash'
require 'active_support/core_ext/object/try'

require 'VMwareWebService/exception'
require 'VMwareWebService/logging'
require 'VMwareWebService/MiqVimVdlMod'
require 'VMwareWebService/esx_thumb_print'
require 'VMwareWebService/vcenter_thumb_print'

class MiqVimVm
  include VMwareWebService::Logging
  include MiqVimVdlVcConnectionMod

  EVM_SNAPSHOT_NAME         = "EvmSnapshot".freeze # TODO: externalize - not VIM specific
  CH_SNAPSHOT_NAME          = /^Consolidate Helper/
  VCB_SNAPSHOT_NAME         = '_VCB-BACKUP_'.freeze
  NETAPP_SNAPSHOT_NAME      = /^smvi/
  VIRTUAL_SCSI_CONTROLLERS  = %w( VirtualBusLogicController
                                  VirtualLsiLogicController
                                  VirtualLsiLogicSASController
                                  ParaVirtualSCSIController ).freeze
  VIRTUAL_NICS              = %w( VirtualE1000
                                  VirtualE1000e
                                  VirtualPCNet32
                                  VirtualVmxnet
                                  VirtualVmxnet2
                                  VirtualVmxnet3 ).freeze
  MAX_SCSI_DEVICES          = 15
  MAX_SCSI_CONTROLLERS      = 4

  attr_reader :name, :localPath, :dsPath, :hostSystem, :uuid, :vmh, :devices, :invObj, :annotation, :customValues, :vmMor

  MIQ_ALARM_PFX = "MiqControl".freeze

  def initialize(invObj, vmh)
    @invObj                 = invObj
    @sic                    = invObj.sic
    @cdSave         = nil
    @cfManager        = nil

    init(vmh)

    @miqAlarmSpecEnabled    = miqAlarmSpecEnabled
    @miqAlarmSpecDisabled   = miqAlarmSpecDisabled

    @cacheLock              = Sync.new
  end # def initialize

  def init(vmh)
    @vmh                    = vmh
    @name                   = vmh['summary']['config']['name']
    @uuid                   = vmh['summary']['config']['uuid']
    @vmMor                  = vmh['summary']['vm']
    @dsPath                 = vmh['summary']['config']['vmPathName']
    @hostSystem             = vmh['summary']['runtime']['host']
    @devices                = vmh['config']['hardware']['device']   if vmh['config'] && vmh['config']['hardware']
    @devices ||= []
    @annotation       = vmh['summary']['config']['annotation']  if vmh['summary']['config']
    @localPath              = @invObj.localVmPath(@dsPath)
    @miqAlarmName           = "#{MIQ_ALARM_PFX}-#{@uuid}"

    @customValues     = {}
    if vmh['availableField'] && vmh['summary']['customValue']
      kton = {}
      vmh['availableField'].each { |af| kton[af['key']] = af['name'] }
      vmh['summary']['customValue'].each { |cv| @customValues[kton[cv['key']]] = cv['value'] }
    end

    @datacenterName         = nil
    @miqAlarmMor            = nil
    @snapshotInfo           = nil
  end

  def refresh
    init(@invObj.refreshVirtualMachine(@vmMor))
  end

  #
  # Called when client is finished using this MiqVimVm object.
  # The server will delete its reference to the object, so the
  # server-side object csn be GC'd
  #
  def release
    # @invObj.releaseObj(self)
  end

  #######################
  # Power state methods.
  #######################

  def start(wait = true)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).start: calling powerOnVM_Task"
    taskMor = @invObj.powerOnVM_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).start: returned from powerOnVM_Task"
    return taskMor unless wait
    waitForTask(taskMor)
  end # def start

  def stop(wait = true)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).stop: calling powerOffVM_Task"
    taskMor = @invObj.powerOffVM_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).stop: returned from powerOffVM_Task"
    return taskMor unless wait
    waitForTask(taskMor)
  end # def stop

  def suspend(wait = true)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).suspend: calling suspendVM_Task"
    taskMor = @invObj.suspendVM_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).suspend: returned from suspendVM_Task"
    return taskMor unless wait
    waitForTask(taskMor)
  end # def suspend

  def reset(wait = true)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reset: calling resetVM_Task"
    taskMor = @invObj.resetVM_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reset: returned from resetVM_Task"
    return taskMor unless wait
    waitForTask(taskMor)
  end

  def rebootGuest
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).rebootGuest: calling rebootGuest"
    @invObj.rebootGuest(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).rebootGuest: returned from rebootGuest"
  end

  def shutdownGuest
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).shutdownGuest: calling shutdownGuest"
    @invObj.shutdownGuest(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).shutdownGuest: returned from shutdownGuest"
  end

  def standbyGuest
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).standbyGuest: calling standbyGuest"
    @invObj.standbyGuest(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).standbyGuest: returned from standbyGuest"
  end

  def powerState
    getProp("runtime.powerState")["runtime"]["powerState"]
  end

  def poweredOn?
    powerState == "poweredOn"
  end

  def poweredOff?
    powerState == "poweredOff"
  end

  def suspended?
    powerState == "suspended"
  end

  def connectionState
    runtime = getProp("runtime.connectionState")
    raise "Failed to retrieve property 'runtime.connectionState' for VM MOR: <#{@vmMor}>" if runtime.nil?
    runtime["runtime"]["connectionState"]
  end

  ############################
  # Template flag operations.
  ############################

  def markAsTemplate
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsTemplate: calling markAsTemplate"
    @invObj.markAsTemplate(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsTemplate: returned from markAsTemplate"
  end

  def markAsVm(pool, host = nil)
    hmor = nil
    hmor = (host.kind_of?(Hash) ? host['MOR'] : host) if host
    pmor = (pool.kind_of?(Hash) ? pool['MOR'] : pool)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsVm: calling markAsVirtualMachine"
    @invObj.markAsVirtualMachine(@vmMor, pmor, hmor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsVm: returned from markAsVirtualMachine"
  end

  def template?
    getProp("config.template")["config"]["template"] == "true"
  end

  ################
  # VM Migration.
  ################

  def migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    hmor = (host.kind_of?(Hash) ? host['MOR'] : host)
    pool = (pool.kind_of?(Hash) ? pool['MOR'] : pool) if pool

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).migrate: calling migrateVM_Task, vm=<#{@vmMor.inspect}>, host=<#{hmor.inspect}>, pool=<#{pool.inspect}>, priority=<#{priority.inspect}>, state=<#{state.inspect}>"
    taskMor = @invObj.migrateVM_Task(@vmMor, pool, hmor, priority, state)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).migrate: returned from migrateVM_Task"
    logger.debug "MiqVimVm::migrate: taskMor = #{taskMor}"
    waitForTask(taskMor)
  end

  def renameVM(newName)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).renameVM: calling rename_Task, vm=<#{@vmMor.inspect}>, newName=<#{newName}>"
    task_mor = @invObj.rename_Task(@vmMor, newName)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).renameVM: returned from rename_Task"
    logger.debug "MiqVimVm::renameVM: taskMor = #{task_mor}"
    waitForTask(task_mor)
  end

  def relocateVM(host, pool = nil, datastore = nil, disk_move_type = nil, transform = nil, priority = "defaultPriority", disk = nil)
    pmor  = (pool.kind_of?(Hash) ? pool['MOR'] : pool)    if pool
    hmor  = (host.kind_of?(Hash) ? host['MOR'] : host)    if host
    dsmor = (datastore.kind_of?(Hash) ? datastore['MOR'] : datastore) if datastore

    rspec = VimHash.new('VirtualMachineRelocateSpec') do |rsl|
      rsl.datastore    = dsmor          if dsmor
      rsl.disk         = disk           if disk
      rsl.diskMoveType = disk_move_type if disk_move_type
      rsl.host         = hmor           if hmor
      rsl.pool         = pmor           if pmor
      rsl.transform    = transform      if transform
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).relocate: calling relocateVM_Task, vm=<#{@vmMor.inspect}>, host=<#{hmor.inspect}>, pool=<#{pool.inspect}>, datastore=<#{dsmor.inspect}>, priority=<#{priority.inspect}>"
    taskMor = @invObj.relocateVM_Task(@vmMor, rspec, priority)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).relocate: returned from relocateVM_Task"
    logger.debug "MiqVimVm::relocate: taskMor = #{taskMor}"
    waitForTask(taskMor)
  end

  def cloneVM_raw(folder, name, spec, wait = true)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).cloneVM_raw: calling cloneVM_Task"
    taskMor = @invObj.cloneVM_Task(@vmMor, folder, name, spec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).cloneVM_raw: returned from cloneVM_Task"
    logger.debug "MiqVimVm::cloneVM_raw: taskMor = #{taskMor}"

    if wait
      rv = waitForTask(taskMor)
      logger.debug "MiqVimVm::cloneVM_raw: rv = #{rv}"
      return rv
    end

    logger.debug "MiqVimVm::cloneVM_raw - no wait: taskMor = #{taskMor}"
    taskMor
  end

  def cloneVM(name, folder,
      pool = nil, host = nil, datastore = nil,
      powerOn = false, template = false, transform = nil,
      config = nil, customization = nil, disk = nil, wait = true)

    fmor  = (folder.kind_of?(Hash) ? folder['MOR'] : folder)
    pmor  = (pool.kind_of?(Hash) ? pool['MOR'] : pool)    if pool
    hmor  = (host.kind_of?(Hash) ? host['MOR'] : host)    if host
    dsmor = (datastore.kind_of?(Hash) ? datastore['MOR'] : datastore) if datastore

    cspec = VimHash.new('VirtualMachineCloneSpec') do |cs|
      cs.powerOn          = powerOn.to_s
      cs.template         = template.to_s
      cs.config           = config    if config
      cs.customization    = customization if customization
      cs.location = VimHash.new('VirtualMachineRelocateSpec') do |csl|
        csl.datastore   = dsmor   if dsmor
        csl.host        = hmor    if hmor
        csl.pool        = pmor    if pmor
        csl.disk        = disk    if disk
        csl.transform   = transform if transform
      end
    end
    cloneVM_raw(fmor, name, cspec, wait)
  end

  # def testCancel(tmor)
  #   fault = VimHash.new('RequestCanceled') do |mf|
  #     mf.faultMessage = VimHash.new('LocalizableMessage') do |lm|
  #       lm.key = "EVM"
  #       lm.message = "EVM test fault message"
  #     end
  #   end
  #   @invObj.setTaskState(tmor, 'error', nil, fault)
  #   # desc = VimHash.new('LocalizableMessage') do |lm|
  #   #     lm.key = "EVM"
  #   #     lm.message = "EVM test task description"
  #   # end
  #   # @invObj.setTaskDescription(tmor, desc)
  # end

  def unregister
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).unregister: calling unregisterVM"
    @invObj.unregisterVM(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).unregister: returned from unregisterVM"
  end

  def destroy
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).destroy: calling destroy_Task"
    taskMor = @invObj.destroy_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).destroy: returned from destroy_Task"
    waitForTask(taskMor)
  end

  ####################
  # Snapshot methods.
  ####################

  def snapshotInfo_locked(refresh = false)
    raise "snapshotInfo_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@snapshotInfo) if @snapshotInfo && !refresh

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      unless (ssp = @invObj.getMoProp_local(@vmMor, "snapshot"))
        @snapshotInfo = nil
        return(nil)
      end

      ssObj = ssp["snapshot"]
      ssMorHash = {}
      rsl = ssObj['rootSnapshotList']
      rsl = [rsl] unless rsl.kind_of?(Array)
      rsl.each { |rs| @invObj.snapshotFixup(rs, ssMorHash) }
      ssObj['ssMorHash'] = ssMorHash
      @snapshotInfo = ssObj
    ensure
      @cacheLock.sync_unlock if unlock
    end

    (@snapshotInfo)
  end # def snapshotInfo_locked

  #
  # Public accessor
  #
  def snapshotInfo(_refresh = false)
    sni = nil
    @cacheLock.synchronize(:SH) do
      sni = @invObj.dupObj(snapshotInfo_locked)
    end
    (sni)
  end

  def createEvmSnapshot(desc, quiesce = "false", wait = true, free_space_percent = 100)
    hasEvm    = hasSnapshot?(EVM_SNAPSHOT_NAME, true)
    hasCh     = hasSnapshot?(CH_SNAPSHOT_NAME, false)
    hasVcb    = hasSnapshot?(VCB_SNAPSHOT_NAME, false)
    hasNetApp = hasSnapshot?(NETAPP_SNAPSHOT_NAME, false)

    if hasEvm || hasCh || hasVcb
      raise MiqException::MiqVimVmSnapshotError, "VM has EVM and consolidate helper snapshots" if hasEvm && hasCh
      raise MiqException::MiqVimVmSnapshotError, "VM already has an EVM snapshot"              if hasEvm
      raise MiqException::MiqVimVmSnapshotError, "VM already has an VCB snapshot"              if hasVcb
      raise MiqException::MiqVimVmSnapshotError, "VM already has a NetApp snapshot"            if hasNetApp
      raise MiqException::MiqVimVmSnapshotError, "VM has a consolidate helper snapshot"
    end
    createSnapshot(EVM_SNAPSHOT_NAME, desc, false, quiesce, wait, free_space_percent)
  end

  def hasSnapshot?(name, refresh = false)
    @cacheLock.synchronize(:SH) do
      return false unless (si = snapshotInfo_locked(refresh))
      return !searchSsTree(si['rootSnapshotList'], 'name', name).nil?
    end
  end

  def searchSsTree(ssObj, key, value)
    ssObj = [ssObj] unless ssObj.kind_of?(Array)
    ssObj.each do |sso|
      if value.kind_of?(Regexp)
        return sso if value =~ sso[key]
      else
        return sso if sso[key] == value
      end
      sso['childSnapshotList'].each { |csso| s = searchSsTree(csso, key, value); return s unless s.nil? }
    end
    nil
  end

  def createSnapshot(name, desc, memory, quiesce, wait = true, free_space_percent = 100)
    logger.debug "MiqVimVm::createSnapshot(#{name}, #{desc}, #{memory}, #{quiesce})"
    cs = connectionState
    raise "MiqVimVm(#{@invObj.server}, #{@invObj.username}).createSnapshot: VM is not connected, connectionState = #{cs}" if cs != "connected"
    snapshot_free_space_check('create', free_space_percent)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).createSnapshot: calling createSnapshot_Task"
    taskMor = @invObj.createSnapshot_Task(@vmMor, name, desc, memory, quiesce)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).createSnapshot: returned from createSnapshot_Task"
    logger.debug "MiqVimVm::createSnapshot: taskMor = #{taskMor}"

    if wait
      snMor = waitForTask(taskMor)
      logger.warn "MiqVimVm::createSnapshot: snMor = #{snMor}"
      return snMor
    end

    logger.debug "MiqVimVm::createSnapshot - no wait: taskMor = #{taskMor}"
    taskMor
  end # def createSnapshot

  def removeSnapshot(snMor, subTree = "false", wait = true, free_space_percent = 100)
    logger.warn "MiqVimVm::removeSnapshot(#{snMor}, #{subTree})"
    snMor = getSnapMor(snMor)
    snapshot_free_space_check('remove', free_space_percent)
    logger.warn "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeSnapshot: calling removeSnapshot_Task: snMor [#{snMor}] subtree [#{subTree}]"
    taskMor = @invObj.removeSnapshot_Task(snMor, subTree)
    logger.warn "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeSnapshot: returned from removeSnapshot_Task: snMor [#{snMor}]"
    logger.debug "MiqVimVm::removeSnapshot: taskMor = #{taskMor}"
    return taskMor unless wait
    waitForTask(taskMor)
  end # def removeSnapshot

  def removeSnapshotByDescription(description, refresh = false, subTree = "false", wait = true, free_space_percent = 100)
    mor = nil
    @cacheLock.synchronize(:SH) do
      return false unless (si = snapshotInfo_locked(refresh))
      sso = searchSsTree(si['rootSnapshotList'], 'description', description)
      return false if sso.nil?
      mor = sso['snapshot']
    end
    removeSnapshot(mor, subTree, wait, free_space_percent)
    true
  end # def removeSnapshotByDescription

  def removeAllSnapshots(free_space_percent = 100)
    logger.debug "MiqVimVm::removeAllSnapshots"
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeAllSnapshots: calling removeAllSnapshots_Task"
    snapshot_free_space_check('remove_all', free_space_percent)
    taskMor = @invObj.removeAllSnapshots_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeAllSnapshots: returned from removeAllSnapshots_Task"
    logger.debug "MiqVimVm::removeAllSnapshots: taskMor = #{taskMor}"
    waitForTask(taskMor)
  end # def removeAllSnapshots

  def revertToSnapshot(snMor)
    logger.debug "MiqVimVm::revertToSnapshot(#{snMor})"
    snMor = getSnapMor(snMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToSnapshot: calling revertToSnapshot_Task"
    taskMor = @invObj.revertToSnapshot_Task(snMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToSnapshot: returned from revertToSnapshot_Task"
    logger.debug "MiqVimVm::revertToSnapshot: taskMor = #{taskMor}"
    waitForTask(taskMor)
  end # def revertToSnapshot

  def revertToCurrentSnapshot
    logger.debug "MiqVimVm::revertToCurrentSnapshot"
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToCurrentSnapshot: calling revertToCurrentSnapshot_Task"
    taskMor = @invObj.revertToCurrentSnapshot_Task(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToCurrentSnapshot: returned from revertToCurrentSnapshot_Task"
    logger.debug "MiqVimVm::revertToCurrentSnapshot: taskMor = #{taskMor}"
    waitForTask(taskMor)
  end # def revertToCurrentSnapshot

  def renameSnapshot(snMor, name, desc)
    logger.debug "MiqVimVm::renameSnapshot(#{snMor}, #{name}, #{desc})"
    snMor = getSnapMor(snMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).renameSnapshot: calling renameSnapshot"
    @invObj.renameSnapshot(snMor, name, desc)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).renameSnapshot: returned from renameSnapshot"
  end # def renameSnapshot

  def snapshot_free_space_check(action, free_space_percent = 100)
    config = @invObj.getMoProp_local(@vmMor, "config")
    disk_space_per_datastore(@devices, snapshot_directory_mor(config)).each do |ds_mor, disk_space_in_kb|
      check_disk_space(action, ds_mor, disk_space_in_kb, free_space_percent)
    end
  end

  def check_disk_space(action, ds_mor, max_disk_space_in_kb, free_space_percent)
    pct = free_space_percent.to_f.zero? ? 100 : free_space_percent
    required_snapshot_space = ((max_disk_space_in_kb * 1024) * (pct.to_f / 100.to_f)).to_i

    # Determine the free space on the datastore used for snapshots
    ds_summary    = @invObj.getMoProp_local(ds_mor, "summary")
    ds_name       = ds_summary.fetch_path('summary', 'name')
    ds_free_space = ds_summary.fetch_path('summary', 'freeSpace').to_i

    # Log results so we can reference if needed.
    if free_space_percent.to_f.zero?
      $log.info "Snapshot #{action} pre-check skipped for Datastore <#{ds_name}> due to Percentage:<#{free_space_percent}>.  Space Free:<#{ds_free_space}>  Disk size:<#{required_snapshot_space}>" if $log
      return
    end

    if ds_free_space < required_snapshot_space
      raise MiqException::MiqVimVmSnapshotError, "Snapshot #{action} aborted.  Datastore <#{ds_name}> does not have enough free space.  Space Free:<#{ds_free_space}>  Required:<#{required_snapshot_space}>  Disk Percentage Used:<#{free_space_percent}>"
    else
      $log.info "Snapshot #{action} pre-check OK.  Datastore <#{ds_name}> has enough free space.  Space Free:<#{ds_free_space}>  Required:<#{required_snapshot_space}>  Disk Percentage Used:<#{free_space_percent}>" if $log
    end
  end

  def disk_space_per_datastore(devices, snapshot_path_mor)
    # Add up the provision size of the disks.  Skip independent disk.
    devices.each_with_object(Hash.new { |h, k| h[k] = 0 }) do |dev, hsh|
      next unless dev.xsiType == 'VirtualDisk'
      next if dev.fetch_path('backing', 'diskMode').to_s.include?('independent_')
      ds_mor = snapshot_path_mor ? snapshot_path_mor : dev.fetch_path('backing', 'datastore')
      hsh[ds_mor] += dev.capacityInKB.to_i
    end
  end

  def snapshot_directory_mor(config)
    if @invObj.apiVersion.to_i >= 5
      redoNotWithParent = config.fetch_path('config', 'extraConfig').detect { |ec| ec['key'] == 'snapshot.redoNotWithParent' }
      return nil if redoNotWithParent.nil? || redoNotWithParent['value'].to_s.downcase != "true"
    end
    snapshot_path = config.fetch_path('config', 'files', 'snapshotDirectory')
    dsn = @invObj.path2dsName(snapshot_path)
    @invObj.dsName2mo_local(dsn)
  end

  def getSnapMor(snMor)
    unless snMor.respond_to?(:vimType)
      logger.debug "MiqVimVm::getSnapMor converting #{snMor} to MOR"
      @cacheLock.synchronize(:SH) do
        raise "getSnapMor: VM #{@dsPath} has no snapshots" unless (sni = snapshotInfo_locked(true))
        raise "getSnapMor: snapshot #{snMor} not found" unless (snObj = sni['ssMorHash'][snMor])
        snMor = snObj['snapshot']
      end
      logger.debug "MiqVimVm::getSnapMor new MOR: #{snMor}"
    end
    (snMor)
  end # def getSnapMor

  #########################
  # Configuration methods.
  #########################

  def getCfg(snap = nil)
    mor = snap ? getSnapMor(snap) : @vmMor
    cfgProps = @invObj.getMoProp(mor, "config")
    raise MiqException::MiqVimError, "Failed to retrieve configuration information for VM" if cfgProps.nil?
    cfgProps = cfgProps["config"]

    cfgHash = {
      'displayname'          => cfgProps['name'],
      'guestos'              => cfgProps['guestId'].downcase.chomp("guest"),
      'uuid.bios'            => cfgProps['uuid'],
      'uuid.location'        => cfgProps['locationId'],
      'memsize'              => cfgProps['hardware']['memoryMB'],
      'cpu_cores_per_socket' => cfgProps['hardware']['numCoresPerSocket'],
      'numvcpu'              => cfgProps['hardware']['numCPU'],
      'config.version'       => cfgProps['version'],
    }

    controllerKeyHash = {}

    1.upto(2) do |_i|
      cfgProps['hardware']['device'].each do |dev|
        case dev.xsiType
        when 'VirtualIDEController'
          tag = "ide#{dev['busNumber']}"
          dev['tag'] = tag
          controllerKeyHash[dev['key']] = dev

        when 'VirtualLsiLogicController', 'VirtualLsiLogicSASController', 'ParaVirtualSCSIController'
          tag = "scsi#{dev['busNumber']}"
          dev['tag'] = tag
          controllerKeyHash[dev['key']] = dev
          cfgHash["#{tag}.present"] = "true"
          cfgHash["#{tag}.virtualdev"] = "lsilogic"

        when 'VirtualBusLogicController'
          tag = "scsi#{dev['busNumber']}"
          dev['tag'] = tag
          controllerKeyHash[dev['key']] = dev
          cfgHash["#{tag}.present"] = "true"
          cfgHash["#{tag}.virtualdev"] = "buslogic"

        when 'VirtualDisk'
          controller_tag = controllerKeyHash.fetch_path(dev['controllerKey'], 'tag')
          next if controller_tag.nil?
          tag = "#{controller_tag}:#{dev['unitNumber']}"
          cfgHash["#{tag}.present"] = "true"
          cfgHash["#{tag}.devicetype"] = "disk"
          cfgHash["#{tag}.filename"] = dev['backing']['fileName']
          cfgHash["#{tag}.mode"] = dev['backing']['diskMode']
        when "VirtualCdrom"
          controller_tag = controllerKeyHash.fetch_path(dev['controllerKey'], 'tag')
          next if controller_tag.nil?
          tag = "#{controller_tag}:#{dev['unitNumber']}"
          cfgHash["#{tag}.present"] = "true"
          if dev['backing']['fileName'].nil?
            cfgHash["#{tag}.devicetype"] = "cdrom-raw"
            cfgHash["#{tag}.filename"] = dev['backing']['deviceName']
          else
            cfgHash["#{tag}.devicetype"] = "cdrom-image"
            cfgHash["#{tag}.filename"] = dev['backing']['fileName']
          end
          cfgHash["#{tag}.startconnected"] = dev['connectable']['startConnected']
        when "VirtualFloppy"
          tag = "floppy#{dev['unitNumber']}"
          cfgHash["#{tag}.present"] = "true"
          if dev['backing']['fileName'].nil?
            cfgHash["#{tag}.filename"] = dev['backing']['deviceName']
          else
            cfgHash["#{tag}.filename"] = dev['backing']['fileName']
          end
          cfgHash["#{tag}.startconnected"] = dev['connectable']['startConnected']
        when "VirtualPCNet32", "VirtualE1000"
          tag = "ethernet#{dev['unitNumber'].to_i - 1}"
          cfgHash["#{tag}.present"] = "true"
          cfgHash["#{tag}.networkname"] = dev['backing']['deviceName']
          cfgHash["#{tag}.generatedaddress"] = dev['macAddress']
          cfgHash["#{tag}.startconnected"] = dev['connectable']['startConnected']
          cfgHash["#{tag}.type"] = dev['deviceInfo']['label']
        end
      end
    end

    cfgHash
  end # def getCfg

  def reconfig(vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reconfig: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reconfig: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end

  def getHardware
    getProp("config.hardware").try(:fetch_path, "config", "hardware") || {}
  end

  def getScsiControllers(hardware = nil)
    hardware ||= getHardware()
    hardware["device"].to_a.select { |dev| VIRTUAL_SCSI_CONTROLLERS.include?(dev.xsiType) }
  end

  def getMemory
    getProp("summary.config.memorySizeMB")["summary"]["config"]["memorySizeMB"].to_i
  end

  def setMemory(memMB)
    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") { |cs| cs.memoryMB = memMB }
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setMemory: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setMemory: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end

  def getNumCPUs
    getProp("summary.config.numCpu")["summary"]["config"]["numCpu"].to_i
  end

  def setNumCPUs(numCPUs)
    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") { |cs| cs.numCPUs = numCPUs }
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setNumCPUs: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setNumCPUs: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end

  def devicesByFilter(filter)
    (@invObj.applyFilter(@devices, filter))
  end

  def connectDevice(dev, connect = true, onStartup = false)
    raise "connectDevice: device #{dev['deviceInfo']['label']} is not a removable device" unless @invObj.hasProp?(dev, "connectable")

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
        vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
          vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
          vdcs.device = @invObj.deepClone(dev)
          vdcs.device.connectable.startConnected = connect.to_s if onStartup
          vdcs.device.connectable.connected = connect.to_s
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).connectDevice: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).connectDevice: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end # def connectDevice

  def attachIsoToCd(isoPath, cd = nil)
    raise "MiqVimVmMod.attachIsoToCd: CD already set" if @cdSave

    unless cd
      cd = devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
      raise "MiqVimVmMod.attachIsoToCd: VM has no CD/DVD drive" if cd.empty?
      cd = cd.first
    end

    if (dsName = @invObj.path2dsName(isoPath)).empty?
      dsMor = nil
    else
      dsMor = @invObj.dsName2mo(dsName)
    end

    @cdSave = @invObj.deepClone(cd)

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
        vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
          vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
          vdcs.device = @invObj.deepClone(cd)
          vdcs.device.connectable.startConnected = "true"
          vdcs.device.connectable.connected = "true"
          vdcs.device.backing = VimHash.new("VirtualCdromIsoBackingInfo") do |vdb|
            vdb.fileName = isoPath
            vdb.datastore = dsMor if dsMor
          end
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).attachIsoToCd: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).attachIsoToCd: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end

  def resetCd
    raise "MiqVimVmMod.resetCd: No previous CD state" unless @cdSave

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
        vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
          vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
          vdcs.device = @cdSave
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).resetCd: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).resetCd: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end

  #
  # Add a new SCSI disk to the VM.
  # Find an existing SCSI controller and add the disk to the next available unit number.
  #
  # If sizeInMB < 0, then assume the backing file already exists.
  #    In this case, backingFile must be the path to the existing VMDK.
  # If backingFile is just the datastore name, "[storage 1]" for example,
  #    file names will be generated as appropriate.
  #
  # Options available:
  # thin_provisioned - if new disk is thin (grow on demand, allowing storage overcommitment) or thick (pre-allocated)
  # dependent       - if new disk is dependent (usual one) or not (meaning no delta file and no live snapshots of running VM)
  # persistent      - if new disk should really save changes or discard them on VM poweroff
  #
  # P.S. Good overview of use cases for dependent / independent and persistent / nonpersistent disks
  # can be found at http://cormachogan.com/2013/04/16/what-are-dependent-independent-disks-persistent-and-non-persisent-modes/
  #
  def addDisk(backingFile, sizeInMB, label = nil, summary = nil, options = {})
    # Remove nil keys if any, since the next line may not work
    options.reject! { |_k, v| v.nil? }
    # Merge default values:
    # - persistent is set to true to be backward compatible
    # - thin_provisioned is set to false explicitly since we call to_s on it further, so nil will not work for us
    options = {:persistent => true, :thin_provisioned => false}.merge(options)
    ck, un = available_scsi_units.first
    raise "addDisk: no SCSI controller found" unless ck

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
        vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
          vdcs.operation = VirtualDeviceConfigSpecOperation::Add
          if sizeInMB < 0
            sizeInMB = -sizeInMB
          else
            vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Create
          end
          vdcs.device = VimHash.new("VirtualDisk") do |vDev|
            vDev.key      = -100 # temp key for creation
            vDev.capacityInKB = sizeInMB * 1024
            vDev.controllerKey  = ck
            vDev.unitNumber   = un
            # The following doesn't seem to work.
            vDev.deviceInfo = VimHash.new("Description") do |desc|
              desc.label    = label
              desc.summary  = summary
            end if label || summary
            vDev.connectable = VimHash.new("VirtualDeviceConnectInfo") do |con|
              con.allowGuestControl = "false"
              con.startConnected    = "true"
              con.connected     = "true"
            end
            if options[:dependent]
              mode = (options[:persistent] ? VirtualDiskMode::Persistent : VirtualDiskMode::Nonpersistent)
            else
              mode = (options[:persistent] ? VirtualDiskMode::Independent_persistent : VirtualDiskMode::Independent_nonpersistent)
            end
            vDev.backing = VimHash.new("VirtualDiskFlatVer2BackingInfo") do |bck|
              bck.diskMode    = mode
              bck.split     = "false"
              bck.thinProvisioned = options[:thin_provisioned].to_s
              bck.writeThrough  = "false"
              bck.fileName    = backingFile
              begin
                dsn = @invObj.path2dsName(@dsPath)
                bck.datastore = @invObj.dsName2mo_local(dsn)
              rescue
                bck.datastore = nil
              end
            end
          end
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addDisk: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addDisk: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end # def addDisk

  #
  # Remove the virtual disk device associated with the given backing file.
  # The backingFile must be the datastore path to the vmdk in question.
  # If deleteBacking is true, the backing file will be deleted, otherwise
  # the disk will be logically removed from the VM and the backing file
  # will remain in place.
  #
  def removeDiskByFile(backingFile, deleteBacking = false)
    raise "removeDiskByFile: false setting for deleteBacking not yet supported" if deleteBacking == false
    controllerKey, key = getDeviceKeysByBacking(backingFile)
    raise "removeDiskByFile: no virtual device associated with: #{backingFile}" unless key
    logger.debug "MiqVimVm::MiqVimVm: backingFile = #{backingFile}"
    logger.debug "MiqVimVm::MiqVimVm: controllerKey = #{controllerKey}, key = #{key}"

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
        vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
          vdcs.operation = VirtualDeviceConfigSpecOperation::Remove
          if deleteBacking
            vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Destroy
          else
            vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Replace
          end
          vdcs.device = VimHash.new("VirtualDisk") do |vDev|
            vDev.key      = key
            vDev.capacityInKB = 0
            vDev.controllerKey  = controllerKey
            vDev.connectable = VimHash.new("VirtualDeviceConnectInfo") do |con|
              con.allowGuestControl = "false"
              con.startConnected    = "true"
              con.connected     = "true"
            end
            vDev.backing = VimHash.new("VirtualDiskFlatVer2BackingInfo") do |bck|
              bck.diskMode    = VirtualDiskMode::Independent_persistent
              bck.split     = "false"
              bck.thinProvisioned = "false"
              bck.writeThrough  = "false"
              bck.fileName    = backingFile
              begin
                dsn = @invObj.path2dsName(@dsPath)
                bck.datastore = @invObj.dsName2mo(dsn)
              rescue
                bck.datastore = nil
              end
            end unless deleteBacking
          end
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeDiskByFile: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeDiskByFile: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end # def removeDiskByFile

  def resizeDisk(backingFile, newSizeInKb)
    disk = getDeviceByBacking(backingFile)
    raise "resizeDisk: no virtual device associated with: #{backingFile}" unless disk
    raise "resizeDisk: cannot reduce the size of a disk" unless newSizeInKb >= Integer(disk.capacityInKB)
    logger.debug "MiqVimVm::resizeDisk: backingFile = #{backingFile} current size = #{device.capacityInKB} newSize = #{newSizeInKb} KB"

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
        vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
          vdcs.operation = VirtualDeviceConfigSpecOperation::Edit

          vdcs.device = VimHash.new("VirtualDisk") do |vDev|
            vDev.backing       = disk.backing
            vDev.capacityInKB  = newSizeInKb
            vDev.controllerKey = disk.controllerKey
            vDev.key           = disk.key
            vDev.unitNumber    = disk.unitNumber
          end
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).resizeDisk: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).resizeDisk: returned from reconfigVM_Task"
    waitForTask(taskMor)
  end

  #
  # Find a SCSI controller and
  # return its key and next available unit number.
  #
  def available_scsi_units(hardware = nil)
    scsi_units       = []
    all_unit_numbers = [*0..MAX_SCSI_DEVICES]

    hardware ||= getHardware()

    devices = hardware["device"]
    scsi_controllers = getScsiControllers(hardware)

    scsi_controllers.sort_by { |s| s["key"].to_i }.each do |scsi_controller|
      # Skip if all controller units are populated
      # Bus has 16 units, controller takes up 1 unit itself
      device = Array(scsi_controller["device"])
      next if device.count >= MAX_SCSI_DEVICES

      # We've found the lowest scsi controller with an available unit
      controller_key = scsi_controller["key"]

      # Get a list of disks on this controller
      disks = devices.select { |dev| device.include?(dev["key"]) }

      # Get a list of all populated units on the controller
      populated_units = disks.collect { |disk| disk["unitNumber"].to_i }
      populated_units << scsi_controller["scsiCtlrUnitNumber"].to_i

      # Pick the lowest available unit number
      available_units  = all_unit_numbers - populated_units

      available_units.each do |unit|
        scsi_units << [controller_key, unit]
      end
    end

    scsi_units
  end # def available_scsi_units

  def available_scsi_buses(hardware = nil)
    scsi_controller_bus_numbers = [*0..MAX_SCSI_CONTROLLERS - 1]

    scsi_controllers = getScsiControllers(hardware)
    scsi_controllers.each do |controller|
      scsi_controller_bus_numbers -= [controller["busNumber"].to_i]
    end

    scsi_controller_bus_numbers
  end

  #
  # Returns the [controllerKey, key] pair for the virtul device
  # associated with the given backing file.
  #
  def getDeviceKeysByBacking(backingFile, hardware = nil)
    dev = getDeviceByBacking(backingFile, hardware)
    return [nil, nil] if dev.nil?
    [dev["controllerKey"], dev["key"]]
  end

  #
  # Returns the device details
  # associated with the given backing file.
  #
  def getDeviceByBacking(backingFile, hardware = nil)
    hardware ||= getHardware

    hardware["device"].to_a.each do |dev|
      next if dev.xsiType != "VirtualDisk"
      next if dev["backing"]["fileName"] != backingFile
      return dev
    end
    nil
  end

  def getDeviceByLabel(device_label, hardware = nil)
    hardware ||= getHardware
    hardware["device"].to_a.detect { |dev| dev["deviceInfo"]["label"] == device_label }
  end

  def getDeviceKeysByLabel(device_label, hardware = nil)
    dev = getDeviceByLabel(device_label, hardware)
    dev.values_at("controllerKey", "key", "unitNumber") unless dev.nil?
  end

  #####################
  # Miq Alarm methods.
  #####################

  #
  # Only called from initialize.
  #
  def miqAlarmSpecEnabled
    VimHash.new("AlarmSpec") do |as|
      as.name     = @miqAlarmName
      as.description  = "#{MIQ_ALARM_PFX} alarm"
      as.enabled    = "true"
      as.expression = VimHash.new("StateAlarmExpression") do |sae|
        sae.operator  = StateAlarmOperator::IsEqual
        sae.statePath = "runtime.powerState"
        sae.type    = @vmMor.vimType
        sae.yellow    = "poweredOn"
        sae.red     = "suspended"
      end
      as.action = VimHash.new("AlarmTriggeringAction") do |aa|
        aa.green2yellow = "true"
        aa.yellow2red   = "false"
        aa.red2yellow   = "true"
        aa.yellow2green = "false"
        aa.action   = VimHash.new("MethodAction") { |aaa| aaa.name = "SuspendVM_Task" }
      end
    end
  end
  private :miqAlarmSpecEnabled

  #
  # Only called from initialize.
  #
  def miqAlarmSpecDisabled
    alarmSpec = @miqAlarmSpecEnabled.clone
    alarmSpec.enabled = "false"
    (alarmSpec)
  end
  private :miqAlarmSpecEnabled

  #
  # If the alarm exists, return its MOR.
  # Otherwise, add the alarm and return its MOR.
  #
  def addMiqAlarm_locked
    raise "addMiqAlarm_locked: cache lock not held" unless @cacheLock.sync_locked?
    if (alarmMor = getMiqAlarm)
      return(alarmMor)
    end

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      alarmManager = @sic.alarmManager
      #
      # Add disabled if VM is running.
      #
      if poweredOff?
        aSpec = @miqAlarmSpecEnabled
      else
        aSpec = @miqAlarmSpecDisabled
      end
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addMiqAlarm_locked: calling createAlarm"
      alarmMor = @invObj.createAlarm(alarmManager, @vmMor, aSpec)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addMiqAlarm_locked: returned from createAlarm"
      @miqAlarmMor = alarmMor
    ensure
      @cacheLock.sync_unlock if unlock
    end

    (alarmMor)
  end # def addMiqAlarm_locked
  protected :addMiqAlarm_locked

  #
  # Public accessor
  #
  def addMiqAlarm
    aMor = nil
    @cacheLock.synchronize(:SH) do
      aMor = addMiqAlarm_locked
    end
    (aMor)
  end

  #
  # Return the MOR of the Miq alarm if it exists, nil otherwise.
  #
  def getMiqAlarm_locked
    raise "addMiqAlarm_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@miqAlarmMor) if @miqAlarmMor

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).getMiqAlarm_locked: calling getAlarm"
      alarms = @invObj.getAlarm(@sic.alarmManager, @vmMor)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).getMiqAlarm_locked: returned from getAlarm"
      alarms.each do |aMor|
        ap = @invObj.getMoProp(aMor, "info.name")
        next unless ap['info']['name'][MIQ_ALARM_PFX]
        @miqAlarmMor = aMor
        return(aMor)
      end if alarms
    ensure
      @cacheLock.sync_unlock if unlock
    end

    (nil)
  end # def getMiqAlarm_locked
  protected :getMiqAlarm_locked

  #
  # Public accessor
  #
  def getMiqAlarm
    aMor = nil
    @cacheLock.synchronize(:SH) do
      aMor = getMiqAlarm_locked
    end
    (aMor)
  end

  def disableMiqAlarm
    @cacheLock.synchronize(:SH) do
      raise "disableMiqAlarm: MiqAlarm not configured for VM #{@dsPath}" unless (aMor = getMiqAlarm_locked)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).disableMiqAlarm: calling reconfigureAlarm"
      @invObj.reconfigureAlarm(aMor, @miqAlarmSpecDisabled)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).disableMiqAlarm: returned from reconfigureAlarm"
    end
  end

  def enableMiqAlarm
    @cacheLock.synchronize(:SH) do
      raise "enableMiqAlarm: MiqAlarm not configured for VM #{@dsPath}" unless (aMor = getMiqAlarm_locked)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).enableMiqAlarm: calling reconfigureAlarm"
      @invObj.reconfigureAlarm(aMor, @miqAlarmSpecEnabled)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).enableMiqAlarm: returned from reconfigureAlarm"
    end
  end

  def removeMiqAlarm
    @cacheLock.synchronize(:SH) do
      return unless (aMor = getMiqAlarm_locked)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeMiqAlarm: calling removeAlarm"
      @invObj.removeAlarm(aMor)
      logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeMiqAlarm: returned from removeAlarm"
      @miqAlarmMor = nil
    end
  end

  def miqAlarmEnabled?
    @cacheLock.synchronize(:SH) do
      return(false) unless (alarmMor = getMiqAlarm_locked)
      props = @invObj.getMoProp(alarmMor, "info.enabled")
      return(props['info.enabled'] == 'true')
    end
  end

  ###########################
  # extraConfig based methods
  ###########################

  def extraConfig
    return @extraConfig unless @extraConfig.nil?

    @extraConfig = {}
    vmh = getProp("config.extraConfig")
    if vmh['config'] && vmh['config']['extraConfig']
      vmh['config']['extraConfig'].each do |ov|
        # Fixes issue where blank values come back as VimHash objects
        value = ov['value'].kind_of?(VimHash) ? VimString.new("", nil, "xsd:string") : ov['value']
        @extraConfig[ov['key']] = value
      end
    end
    @extraConfig
  end

  def getExtraConfigAttributes(attributes)
    rh = {}
    attributes.each { |a| rh[a] = extraConfig[a] }
    (rh)
  end

  def setExtraConfigAttributes(hash)
    raise "setExtraConfigAttributes: no attributes specified" if !hash.kind_of?(Hash) || hash.empty?

    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.extraConfig = VimArray.new("ArrayOfOptionValue") do |vmcs_eca|
        hash.each do |k, v|
          vmcs_eca << VimHash.new("OptionValue") do |ov|
            ov.key   = k.to_s
            ov.value = VimString.new(v.to_s, nil, "xsd:string")
          end
        end
      end
    end

    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setExtraConfigAttributes: calling reconfigVM_Task"
    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setExtraConfigAttributes: returned from reconfigVM_Task"
    waitForTask(taskMor)

    @extraConfig = nil
    hash
  end

  def addExtraConfigPrefix(hash, prefix)
    hash.each_with_object({}) do |(k, v), rh|
      k = "#{prefix}.#{k}"
      rh[k] = v
    end
  end

  def removeExtraConfigPrefix(hash, prefix)
    hash.each_with_object({}) do |(k, v), rh|
      k = k[prefix.length + 1..-1]
      rh[k] = v
    end
  end

  #################
  # - vmSafe
  #################

  VmSafeAttributePrefix = 'vmsafe'
  VmSafeAttributes = ['vmsafe.enable', 'vmsafe.agentAddress', 'vmsafe.agentPort', 'vmsafe.failOpen', 'vmsafe.immutableVM', 'vmsafe.timeoutMS']

  def getVmSafeAttributes
    attrs = getExtraConfigAttributes(VmSafeAttributes)
    removeExtraConfigPrefix(attrs, VmSafeAttributePrefix)
  end

  def setVmSafeAttributes(hash)
    attrs = addExtraConfigPrefix(hash, VmSafeAttributePrefix)
    attrs.keys.each do |k|
      raise "setVmSafeAttributes: unrecognized attribute: #{k[VmSafeAttributePrefix.length + 1..-1]}" unless VmSafeAttributes.include?(k)
    end
    setExtraConfigAttributes(attrs)
  end

  def vmsafeEnabled?
    return false unless (ve = extraConfig['vmsafe.enable'])
    ve.casecmp("true") == 0
  end

  ####################
  # - remoteDisplayVnc
  ####################

  RemoteDisplayVncAttributePrefix = 'RemoteDisplay.vnc'
  RemoteDisplayVncAttributes = ['RemoteDisplay.vnc.enabled', 'RemoteDisplay.vnc.key', 'RemoteDisplay.vnc.password', 'RemoteDisplay.vnc.port']

  def getRemoteDisplayVncAttributes
    attrs = getExtraConfigAttributes(RemoteDisplayVncAttributes)
    removeExtraConfigPrefix(attrs, RemoteDisplayVncAttributePrefix)
  end

  def setRemoteDisplayVncAttributes(hash)
    attrs = addExtraConfigPrefix(hash, RemoteDisplayVncAttributePrefix)
    attrs.each do |k, v|
      raise "setRemoteDisplayVncAttributes: unrecognized attribute: #{k[RemoteDisplayVncAttributePrefix.length + 1..-1]}" unless RemoteDisplayVncAttributes.include?(k)
      raise "setRemoteDisplayVncAttributes: RemoteDisplay.vnc.key cannot be set" if k == "RemoteDisplay.vnc.key"
      raise "setRemoteDisplayVncAttributes: RemoteDisplay.vnc.password cannot be longer than 8 characters" if k == "RemoteDisplay.vnc.password" && v.to_s.length > 8
    end
    setExtraConfigAttributes(attrs)
  end

  def remoteDisplayVncEnabled?
    return false unless (ve = extraConfig['RemoteDisplay.vnc.enabled'])
    ve.casecmp("true") == 0
  end

  ########################
  # Custom field methods.
  ########################

  def cfManager
    @cfManager = @invObj.getMiqCustomFieldsManager unless @cfManager
    @cfManager
  end

  def setCustomField(name, value)
    fk = cfManager.getFieldKey(name, @vmMor.vimType)
    cfManager.setField(@vmMor, fk, value)
  end

  ###################
  # Utility Methods.
  ###################

  def logUserEvent(msg)
    @invObj.logUserEvent(@vmMor, msg)
  end

  def getProp(path = nil)
    @invObj.getMoProp(@vmMor, path)
  end # def getProp

  def waitForTask(tmor)
    @invObj.waitForTask(tmor, self.class.to_s)
  end

  def pollTask(tmor)
    @invObj.pollTask(tmor, self.class.to_s)
  end

  def acquireMksTicket
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).acquireMksTicket: calling acquireMksTicket"
    rv = @invObj.acquireMksTicket(@vmMor)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).acquireMksTicket: returned from acquireMksTicket"
    (rv)
  end # def acquireMksTicket

  def acquireTicket(ticketType)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).acquireTicket: calling acquireTicket"
    rv = @invObj.acquireTicket(@vmMor, ticketType)
    logger.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).acquireTicket: returned from acquireTicket"
    (rv)
  end # def acquireTicket

  def datacenterName
    @cacheLock.synchronize(:SH) do
      @datacenterName = @invObj.vmDatacenterName(@vmMor) unless @datacenterName
      return @datacenterName
    end
  end
  private :datacenterName

  def vixVmxSpec
    #
    # For VDDK 1.1 and later, this is the preferred form for the vmxspec.
    #
    "moref=#{@vmMor}"
    #
    # For pre 1.1 versions of VDDK, this vmxspec must be used.
    #
    # return "#{@invObj.dsRelativePath(@dsPath)}?dcPath=#{datacenterName}&dsName=#{@invObj.path2dsName(@dsPath)}"
  end
end # module MiqVimVmMod
