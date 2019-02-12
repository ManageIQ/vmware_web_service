require 'active_support/core_ext/numeric/bytes'
require 'rbvmomi/vim'
require 'VMwareWebService/VimTypes'

class VimService
  attr_reader :sic, :about, :apiVersion, :isVirtualCenter, :v20, :v2, :v4, :serviceInstanceMor, :vim

  def initialize(host, namespace: "urn:vim25", ssl: true, insecure: true, path: "/sdk", port: 443, vc_version: "6.7")
    @vim = RbVmomi::VIM.new(
      :ns       => namespace,
      :host     => host,
      :ssl      => ssl,
      :insecure => insecure,
      :path     => path,
      :port     => port,
      :rev      => vc_version,
    )

    @serviceInstanceMor = vim.serviceInstance

    @sic = retrieveServiceContent

    @about           = @sic.about
    @apiVersion      = @about.apiVersion
    @v20             = @apiVersion =~ /2\.0\..*/
    @v2              = @apiVersion =~ /2\..*/
    @v4              = @apiVersion =~ /4\..*/
    @isVirtualCenter = @about.apiType == "VirtualCenter"
  end

  def acquireCloneTicket(sm)
    sm.AcquireCloneTicket
  end

  def acquireMksTicket(mor)
    mor.AcquireMksTicker
  end

  def acquireTicket(mor, ticketType)
    mor.AcquireTicker(:ticketType => ticketType)
  end

  def addHost_Task(clustMor, spec, asConnected, resourcePool = nil, license = nil)
    clustMor.AddHost_Task(:spec => spec, :asConnected => asConnected, :resourcePool => resourcePool, :license => license)
  end

  def addInternetScsiSendTargets(hssMor, iScsiHbaDevice, targets)
    hssMor.AddInternetScsiSendTargets(:iScsiHbaDevice => iScsiHbaDevice, :targets => targets)
  end

  def addInternetScsiStaticTargets(hssMor, iScsiHbaDevice, targets)
    hssMor.AddInternetScsiStaticTargets(:iScsiHbaDevice => iScsiHbaDevice, :targets => targets)
  end

  def addStandaloneHost_Task(folderMor, spec, addConnected, license = nil)
    folderMor.AddStandaloneHost_Task(:spec => spec, :addConnected => addConnected, :license => license)
  end

  def browseDiagnosticLog(diagnosticManager, host, key, start, lines)
    diagnosticManager.BrowseDiagnosticLog(:host => host, :key => key, :start => start, :lines => lines)
  end

  def cancelRetrievePropertiesEx(propCol, token)
    propCol.CancelRetrievePropertiesEx(:token => token)
  end

  def cancelTask(tmor)
    tmor.CancelTask
  end

  def cancelWaitForUpdates(propCol)
    propCol.CancelWaitForUpdates
  end

  def cloneVM_Task(vmMor, fmor, name, cspec)
    vmMor.CloneVM_Task(:folder => fmor, :name => name, :spec => cspec)
  end

  def continueRetrievePropertiesEx(propCol, token)
    propCol.ContinueRetrievePropertiesEx(:token => token)
  end

  def createAlarm(alarmManager, mor, aSpec)
    alarmManager.CreateAlarm(:entity => mor, :spec => aSpec)
  end

  def createCollectorForEvents(eventManager, eventFilterSpec)
    eventManager.CreateCollectorForEvents(:filter => eventFilterSpec)
  end

  def createCustomizationSpec(csmMor, item)
    csmMor.CreateCustomizationSpec(:item => item)
  end

  def createFilter(propCol, pfSpec, partialUpdates)
    propCol.CreateFilter(:spec => pfSpec, :partialUpdates => partialUpdates)
  end

  def createFolder(pfMor, fname)
    pfMor.CreateFolder(:name => fname)
  end

  def createNasDatastore(dssMor, spec)
    dssMor.CreateNasDatastore(:spec => spec)
  end

  def createSnapshot_Task(vmMor, name, desc, memory, quiesce)
    vmMor.CreateSnapshot_Task(:name => name, :description => desc, :memory => memory, :quiesce => quiesce)
  end

  def createVM_Task(fMor, vmcs, pool, hMor)
    fMor.CreateVM_Task(:config => vmcs, :pool => pool, :host => hMor)
  end

  def currentTime
    serviceInstanceMor.CurrentTime
  end

  def customizationSpecItemToXml(csmMor, item)
    csmMor.CustomizationSpecItemToXml(:item => item)
  end

  def deleteCustomizationSpec(csmMor, name)
    csmMor.DeleteCustomizationSpec(:name => name)
  end

  def deselectVnicForNicType(vnmMor, nicType, device)
    vnmMor.DeselectVnicForNicType(:nicType => nicType, :device => device)
  end

  def destroy_Task(mor)
    mor.Destroy_Task
  end

  def destroyCollector(collectorMor)
    collectorMor.DestroyCollector
  end

  def destroyPropertyFilter(filterSpecRef)
    filterSpecRef.DestroyPropertyFilter
  end

  def disableRuleset(fwsMor, rskey)
    fwsMor.DisableRuleset(:id => rskey)
  end

  def doesCustomizationSpecExist(csmMor, name)
    csmMor.DoesCustomizationSpecExist(:name => name)
  end

  def enableRuleset(fwsMor, rskey)
    fwsMor.EnableRuleset(:id => rskey)
  end

  def enterMaintenanceMode_Task(hMor, timeout = 0, evacuatePoweredOffVms = false)
    hMor.EnterMaintenanceMode_Task(:timeout => timeout, :evacuatePoweredOffVms => evacuatePoweredOffVms)
  end

  def exitMaintenanceMode_Task(hMor, timeout = 0)
    hMor.ExitMaintenanceMode_Task(:timeout => timeout)
  end

  def getAlarm(alarmManager, mor)
    alarmManager.GetAlarm(:entity => mor)
  end

  def getCustomizationSpec(csmMor, name)
    csmMor.GetCustomizationSpec(:name => name)
  end

  def login(sessionManager, username, password)
    sessionManager.Login(:userName => username, :password => password)
  end

  def logout(sessionManager)
    sessionManager.Logout
  end

  def logUserEvent(eventManager, entity, msg)
    eventManager.LogUserEvent(:entity => entity, :msg => msg)
  end

  def markAsTemplate(vmMor)
    vmMor.MarkAsTemplate
  end

  def markAsVirtualMachine(vmMor, pmor, hmor = nil)
    vmMor.MarkAsVirtualMachine(:pool => pmor, :host => hmor)
  end

  def migrateVM_Task(vmMor, pmor = nil, hmor = nil, priority = "defaultPriority", state = nil)
    vmMor.MigrateVM_Task(:pool => pmor, :hmor => hmor, :priority => priority, :state => state)
  end

  def moveIntoFolder_Task(fMor, oMor)
    fMor.MoveIntoFolder_Task(:list => oMor)
  end

  def relocateVM_Task(vmMor, cspec, priority = "defaultPriority")
    vmMor.RelocateVM_Task(:spec => cspec, :priority => priority)
  end

  def powerDownHostToStandBy_Task(hMor, timeoutSec = 0, evacuatePoweredOffVms = false)
    hMor.PowerDownHostToStandBy_Task(:timeoutSec => timeoutSec, :evacuatePoweredOffVms => evacuatePoweredOffVms)
  end

  def powerOffVM_Task(vmMor)
    vmMor.PowerOffVM_Task
  end

  def powerOnVM_Task(vmMor, hMor = nil)
    vmMor.PowerOnVM_Task(:host => hMor)
  end

  def powerUpHostFromStandBy_Task(hMor, timeoutSec = 0)
    hMor.PowerUpHostFromStandBy_Task(:timeoutSec => timeoutSec)
  end

  def queryAvailablePerfMetric(perfManager, entity, beginTime = nil, endTime = nil, intervalId = nil)
    perfManager.QueryAvailablePerfMetric(
      :entity     => entity,
      :beginTime  => beginTime,
      :endTime    => endTime,
      :intervalId => intervalId
    )
  end

  def queryDescriptions(diagnosticManager, entity)
    diagnosticManager.QueryDescriptions(:host => entity)
  end

  def queryDvsConfigTarget(dvsManager, hmor, dvs)
    dvsManager.QueryDvsConfigTarget(:host => hmor, :dvs => dvs)
  end

  def queryNetConfig(vnmMor, nicType)
    vnmMor.QueryNetConfig(:nicType => nicType)
  end

  def queryOptions(omMor, name)
    omMor.QueryOptions(:name => name)
  end

  def queryPerf(perfManager, querySpec)
    perfManager.QueryPerf(:querySpec => querySpec)
  end

  def queryPerfComposite(perfManager, querySpec)
    perfManager.QueryPerfComposite(:querySpec => querySpec)
  end

  def queryPerfProviderSummary(perfManager, entity)
    perfManager.QueryPerfProviderSummary(:entity => entity)
  end

  def readNextEvents(ehcMor, maxCount)
    ehcMor.ReadNextEvents(:maxCount => maxCount)
  end

  def readPreviousEvents(ehcMor, maxCount)
    ehcMor.ReadPreviousEvents(:maxCount => maxCount)
  end

  def rebootGuest(vmMor)
    vmMor.RebootGuest
  end

  def rebootHost_Task(hMor, force = false)
    hMor.RebootHost_Task(:force => force)
  end

  def reconfigureAlarm(aMor, aSpec)
    aMor.ReconfigureAlarm(:spec => aSpec)
  end

  def reconfigVM_Task(vmMor, vmConfigSpec)
    vmMor.ReconfigVM_Task(:spec => vmConfigSpec)
  end

  def refreshFirewall(fwsMor)
    fwsMor.RefreshFirewall
  end

  def refreshNetworkSystem(nsMor)
    nsMor.RefreshNetworkSystem
  end

  def refreshServices(ssMor)
    ssMor.RefreshServices
  end

  def registerVM_Task(fMor, path, name, asTemplate, pmor, hmor)
    fMor.RegisterVM_Task(:path => path, :name => name, :asTemplate => asTemplate, :pool => pmor, :host => hmor)
  end

  def removeAlarm(aMor)
    aMor.RemoveAlarm
  end

  def removeAllSnapshots_Task(vmMor)
    vmMor.RemoveAllSnapshots_Task
  end

  def removeSnapshot_Task(snMor, subTree)
    snMor.RemoveSnapshot_Task(:removeChildren => subTree)
  end

  def rename_Task(vmMor, newName)
    vmMor.Rename_Task(:newName => newName)
  end

  def renameSnapshot(snMor, name, desc)
    snMor.RenameSnapshot(:name => name, :description => desc)
  end

  def resetCollector(collectorMor)
    collectionMor.ResetCollector
  end

  def resetVM_Task(vmMor)
    vmMor.ResetVM_Task
  end

  def restartService(ssMor, skey)
    ssMor.RestartService(:id => skey)
  end

  def retrieveProperties(propCol, specSet)
    propCol.RetrieveProperties(:specSet => specSet)
  end

  def retrievePropertiesEx(propCol, specSet, max_objects = nil)
    propCol.RetrievePropertiesEx(
      :specSet => specSet,
      :options => RbVmomi::VIM::RetrieveOptions(
        :maxObjects => max_objects
      ),
    )
  end

  def retrievePropertiesIter(propCol, specSet, max_objects = nil)
    result = retrievePropertiesEx(propCol, specSet, max_objects)

    while result
      result.objects.each { |oc| yield oc }

      # if there is no token returned then all results fit in a single page
      # and we are done
      break if result.token.nil?

      # there is more than one page of result so continue getting the rest
      result = continueRetrievePropertiesEx(propCol, result.token)
    end
  rescue
    # if for some reason the caller breaks out of the block let the
    # server know we are going to cancel this retrievePropertiesEx call
    cancelRetrievePropertiesEx(propCol, result.token) if result&.token
  end

  def retrievePropertiesCompat(propCol, specSet, max_objects = nil)
    objects = []
    retrievePropertiesIter(propCol, specSet, max_objects) { |oc| objects << oc }
    objects
  end

  def retrieveServiceContent
    serviceInstanceMor.RetrieveServiceContent
  end

  def revertToCurrentSnapshot_Task(vmMor)
    vmMor.RevertToCurrentSnapshot_Task
  end

  def revertToSnapshot_Task(snMor)
    snMor.RevertToSnapshot_Task
  end

  def rewindCollector(collectorMor)
    collectorMor.RewindCollector
  end

  def searchDatastore_Task(browserMor, dsPath, searchSpec)
    browserMor.SearchDatastore_Task(:datastorePath => dsPath, :searchSpec => searchSpec)
  end

  def searchDatastoreSubFolders_Task(browserMor, dsPath, searchSpec)
    browserMor.SearchDatastoreSubFolders_Task(:datastorePath => dsPath, :searchSpec => searchSpec)
  end

  def selectVnicForNicType(vnmMor, nicType, device)
    vnmMor.SelectVnicForNicType(:nicType => nicType, :device => device)
  end

  def setCollectorPageSize(collector, maxCount)
    collector.SetCollectorPageSize(:maxCount => maxCount)
  end

  def setField(cfManager, mor, key, value)
    cfManager.SetField(:entity => mor, :key => key, :value => value)
  end

  def setTaskDescription(tmor, description)
    tmor.SetTaskDescription(:description => description)
  end

  def setTaskState(tmor, state, result = nil, fault = nil)
    tmor.SetTaskState(:state => state, :result => result, :fault => fault)
  end

  def shutdownGuest(vmMor)
    vmMor.ShutdownGuest
  end

  def shutdownHost_Task(hMor, force = false)
    hMor.ShutdownHost_Task(:force => force)
  end

  def standbyGuest(vmMor)
    vmMor.StandbyGuest
  end

  def startService(ssMor, skey)
    ssMor.StartService(:id => skey)
  end

  def stopService(ssMor, skey)
    ssMor.StopService(:id => skey)
  end

  def suspendVM_Task(vmMor)
    vmMor.SuspendVM_Task
  end

  def uninstallService(ssMor, skey)
    ssMor.UninstallService(:id => skey)
  end

  def unregisterVM(vmMor)
    vmMor.UnregisterVM
  end

  def updateDefaultPolicy(fwsMor, defaultPolicy)
    fwsMor.UpdateDefaultPolicy(:defaultPolicy => defaultPolicy)
  end

  def updateServicePolicy(sMor, skey, policy)
    sMor.UpdateServicePolicy(:id => skey, :policy => policy)
  end

  def updateSoftwareInternetScsiEnabled(hssMor, enabled)
    hssMor.UpdateSoftwareInternetScsiEnabled(:enabled => enabled)
  end

  def waitForUpdates(propCol, version = nil)
    propCol.WaitForUpdates(:version => version)
  end

  def waitForUpdatesEx(propCol, version = nil, options = {})
    propCol.WaitForUpdatesEx(
      :version => version,
      :options => RbVmomi::VIM::WaitOptions(
        :maxObjectUpdates => options[:max_objects],
        :maxWaitSeconds   => options[:max_wait],
      ),
    )
  end

  def xmlToCustomizationSpecItem(csmMor, specItemXml)
    csmMor.XmlToCustomizationSpecItem(:specItemXml => specItemXml)
  end
end
