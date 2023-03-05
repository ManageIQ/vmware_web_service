require 'active_support/core_ext/numeric/bytes'
require 'VMwareWebService/logging'
require 'VMwareWebService/VimTypes'

class VimService
  include VMwareWebService::Logging

  attr_reader :sic, :about, :apiVersion, :isVirtualCenter, :v20, :v2, :v4, :v5, :v6, :serviceInstanceMor, :session_cookie
  attr_accessor :vim
  private :vim

  def initialize(uri)
    require "rbvmomi"
    self.vim = RbVmomi::VIM.new(
      :ns       => "urn:vim25",
      :ssl      => true,
      :insecure => true,
      :port     => uri.port,
      :path     => uri.path,
      :host     => uri.host,
      :rev      => "6.5"
    )

    @serviceInstanceMor = rbvmomi_to_vim_types(vim.serviceInstance)
    @session_cookie     = nil

    @sic = retrieveServiceContent

    @about           = @sic.about
    @apiVersion      = @about.apiVersion
    @v20             = @apiVersion =~ /2\.0\..*/
    @v2              = @apiVersion =~ /2\..*/
    @v4              = @apiVersion =~ /4\..*/
    @v5              = @apiVersion =~ /5\..*/
    @v6              = @apiVersion =~ /6\..*/
    @isVirtualCenter = @about.apiType == "VirtualCenter"
  end

  def acquireCloneTicket(sm)
    rbvmomi_to_vim_types(vim_to_rbvmomi_types(sm).AcquireCloneTicket)
  end

  def acquireMksTicket(mor)
    rbvmomi_to_vim_types(vim_to_rbvmomi_types(mor).AcquireMksTicket)
  end

  def acquireTicket(mor, ticket_type)
    rbvmomi_to_vim_types(vim_to_rbvmomi_types(mor).AcquireTicket(:ticketType => ticket_type))
  end

  def addHost_Task(cluster_mor, spec, as_connected, resource_pool = nil, license = nil)
    task_mor = vim_to_rbvmomi_types(cluster_mor).AddHost_Task(
      :spec         => vim_to_rbvmomi_types(spec),
      :asConnected  => as_connected,
      :resourcePool => vim_to_rbvmomi_types(resource_pool),
      :license      => license
    )

    rbvmomi_to_vim_types(task_mor)
  end

  def addInternetScsiSendTargets(hssMor, iScsiHbaDevice, targets)
    response = vim_to_rbvmomi_types(hssMor).AddInternetScsiSendTargets(
      :iScsiHbaDevice => vim_to_rbvmomi_types(iScsiHbaDevice),
      :targets        => vim_to_rbvmomi_types(targets)
    )

    rbvmomi_to_vim_types(response)
  end

  def addInternetScsiStaticTargets(hssMor, iScsiHbaDevice, targets)
    response = invoke("n1:AddInternetScsiStaticTargets") do |message|
      message.add "n1:_this", hssMor do |i|
        i.set_attr "type", hssMor.vimType
      end
      message.add "n1:iScsiHbaDevice", iScsiHbaDevice
      if targets.kind_of?(Array)
        targets.each do |t|
          message.add "n1:targets" do |i|
            i.set_attr "xsi:type", t.xsiType
            marshalObj(i, t)
          end
        end
      else
        message.add "n1:targets" do |i|
          i.set_attr "xsi:type", targets.xsiType
          marshalObj(i, targets)
        end
      end
    end
    (parse_response(response, 'AddInternetScsiStaticTargetsResponse'))
  end

  def addStandaloneHost_Task(folderMor, spec, addConnected, license = nil)
    response = invoke("n1:AddStandaloneHost_Task") do |message|
      message.add "n1:_this", folderMor do |i|
        i.set_attr "type", folderMor.vimType
      end
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", spec.xsiType
        marshalObj(i, spec)
      end
      message.add "n1:addConnected", addConnected
      message.add "n1:license", license unless license.nil?
    end
    (parse_response(response, 'AddStandaloneHost_TaskResponse')['returnval'])
  end

  def browseDiagnosticLog(diagnosticManager, host, key, start, lines)
    response = invoke("n1:BrowseDiagnosticLog") do |message|
      message.add "n1:_this", diagnosticManager do |i|
        i.set_attr "type", diagnosticManager.vimType
      end
      message.add "n1:host", host do |i|
        i.set_attr "type", host.vimType
      end if host
      message.add "n1:key", key
      message.add "n1:start", start if start
      message.add "n1:lines", lines if lines
    end
    (parse_response(response, 'BrowseDiagnosticLogResponse')['returnval'])
  end

  def cancelTask(tmor)
    response = invoke("n1:CancelTask") do |message|
      message.add "n1:_this", tmor do |i|
        i.set_attr "type", tmor.vimType
      end
    end
    (parse_response(response, 'CancelTaskResponse'))
  end

  def cancelWaitForUpdates(prop_col)
    rbvmomi_to_vim_types(vim_to_rbvmomi_types(prop_col).CancelWaitForUpdates)
  end

  def cloneVM_Task(vmMor, fmor, name, cspec)
    response = invoke("n1:CloneVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
      message.add "n1:folder", fmor do |i|
        i.set_attr "type", fmor.vimType
      end
      message.add "n1:name", name
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", cspec.xsiType
        marshalObj(i, cspec)
      end
    end
    (parse_response(response, 'CloneVM_TaskResponse')['returnval'])
  end

  def continueRetrievePropertiesEx(propCol, token)
    response = invoke("n1:ContinueRetrievePropertiesEx") do |message|
      message.add "n1:_this", propCol do |i|
        i.set_attr "type", propCol.vimType
      end
      message.add "n1:token", token
    end
    (parse_response(response, 'ContinueRetrievePropertiesExResponse')['returnval'])
  end

  def createAlarm(alarmManager, mor, aSpec)
    response = invoke("n1:CreateAlarm") do |message|
      message.add "n1:_this", alarmManager do |i|
        i.set_attr "type", alarmManager.vimType
      end
      message.add "n1:entity", mor do |i|
        i.set_attr "type", mor.vimType
      end
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", aSpec.xsiType
        marshalObj(i, aSpec)
      end
    end
    (parse_response(response, 'CreateAlarmResponse')['returnval'])
  end

  def createCollectorForEvents(eventManager, eventFilterSpec)
    response = invoke("n1:CreateCollectorForEvents") do |message|
      message.add "n1:_this", eventManager do |i|
        i.set_attr "type", eventManager.vimType
      end
      message.add "n1:filter" do |i|
        i.set_attr "xsi:type", eventFilterSpec.xsiType
        marshalObj(i, eventFilterSpec)
      end
    end
    (parse_response(response, 'CreateCollectorForEventsResponse')['returnval'])
  end

  def createCustomizationSpec(csmMor, item)
    response = invoke("n1:CreateCustomizationSpec") do |message|
      message.add "n1:_this", csmMor do |i|
        i.set_attr "type", csmMor.vimType
      end
      message.add "n1:item" do |i|
        i.set_attr "xsi:type", item.xsiType
        marshalObj(i, item)
      end
    end
    (parse_response(response, 'CreateCustomizationSpecResponse')['returnval'])
  end

  def createFilter(property_collector, spec, partial_updates)
    result = vim_to_rbvmomi_types(property_collector).CreateFilter(
      :spec           => vim_to_rbvmomi_types(spec),
      :partialUpdates => partial_updates
    )

    rbvmomi_to_vim_types(result)
  end

  def createFolder(pfMor, fname)
    response = invoke("n1:CreateFolder") do |message|
      message.add "n1:_this", pfMor do |i|
        i.set_attr "type", pfMor.vimType
      end
      message.add "n1:name", fname
    end
    (parse_response(response, 'CreateFolderResponse')['returnval'])
  end

  def createNasDatastore(dssMor, spec)
    response = invoke("n1:CreateNasDatastore") do |message|
      message.add "n1:_this", dssMor do |i|
        i.set_attr "type", dssMor.vimType
      end
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", spec.xsiType
        marshalObj(i, spec)
      end
    end
    (parse_response(response, 'CreateNasDatastoreResponse')['returnval'])
  end

  def createSnapshot_Task(vmMor, name, desc, memory, quiesce)
    response = invoke("n1:CreateSnapshot_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
      message.add "n1:name", name
      message.add "n1:description", desc  if desc
      message.add "n1:memory", memory.to_s
      message.add "n1:quiesce", quiesce
    end
    (parse_response(response, 'CreateSnapshot_TaskResponse')['returnval'])
  end

  def createVM_Task(fMor, vmcs, pool, hMor)
    response = invoke("n1:CreateVM_Task") do |message|
      message.add "n1:_this", fMor do |i|
        i.set_attr "type", fMor.vimType
      end
      message.add "n1:config" do |i|
        i.set_attr "xsi:type", vmcs.xsiType
        marshalObj(i, vmcs)
      end
      message.add "n1:pool", pool do |i|
        i.set_attr "type", "ResourcePool"
      end
      # hMor is not mandatory since it's ok to miss it for DRS clusters or single host clusters
      unless hMor.nil?
        message.add "n1:host", hMor do |i|
          i.set_attr "type", hMor.vimType
        end
      end
    end
    parse_response(response, 'CreateVM_TaskResponse')['returnval']
  end

  def currentTime
    vim_to_rbvmomi_types(serviceInstanceMor).CurrentTime
  end

  def customizationSpecItemToXml(csmMor, item)
    response = invoke("n1:CustomizationSpecItemToXml") do |message|
      message.add "n1:_this", csmMor do |i|
        i.set_attr "type", csmMor.vimType
      end
      message.add "n1:item" do |i|
        i.set_attr "xsi:type", item.xsiType
        marshalObj(i, item)
      end
    end
    (parse_response(response, 'CustomizationSpecItemToXmlResponse')['returnval'])
  end

  def deleteCustomizationSpec(csmMor, name)
    response = invoke("n1:DeleteCustomizationSpec") do |message|
      message.add "n1:_this", csmMor do |i|
        i.set_attr "type", csmMor.vimType
      end
      message.add "n1:name", name
    end
    (parse_response(response, 'DeleteCustomizationSpecResponse'))['returnval']
  end

  def deselectVnicForNicType(vnmMor, nicType, device)
    response = invoke("n1:DeselectVnicForNicType") do |message|
      message.add "n1:_this", vnmMor do |i|
        i.set_attr "type", vnmMor.vimType
      end
      message.add "n1:nicType", nicType
      message.add "n1:device", device
    end
    (parse_response(response, 'DeselectVnicForNicTypeResponse'))
  end

  def destroy_Task(mor)
    response = invoke("n1:Destroy_Task") do |message|
      message.add "n1:_this", mor do |i|
        i.set_attr "type", mor.vimType
      end
    end
    (parse_response(response, 'Destroy_TaskResponse')['returnval'])
  end

  def destroyCollector(collectorMor)
    response = invoke("n1:DestroyCollector") do |message|
      message.add "n1:_this", collectorMor do |i|
        i.set_attr "type", collectorMor.vimType
      end
    end
    (parse_response(response, 'DestroyCollectorResponse'))
  end

  def destroyPropertyFilter(filterSpecRef)
    response = invoke("n1:DestroyPropertyFilter") do |message|
      message.add "n1:_this", filterSpecRef do |i|
        i.set_attr "type", filterSpecRef.vimType
      end
    end
    (parse_response(response, 'DestroyPropertyFilterResponse'))
  end

  def disableRuleset(fwsMor, rskey)
    response = invoke("n1:DisableRuleset") do |message|
      message.add "n1:_this", fwsMor do |i|
        i.set_attr "type", fwsMor.vimType
      end
      message.add "n1:id", rskey
    end
    (parse_response(response, 'DisableRulesetResponse'))
  end

  def doesCustomizationSpecExist(csmMor, name)
    response = invoke("n1:DoesCustomizationSpecExist") do |message|
      message.add "n1:_this", csmMor do |i|
        i.set_attr "type", csmMor.vimType
      end
      message.add "n1:name", name
    end
    (parse_response(response, 'DoesCustomizationSpecExistResponse'))['returnval']
  end

  def enableRuleset(fwsMor, rskey)
    response = invoke("n1:EnableRuleset") do |message|
      message.add "n1:_this", fwsMor do |i|
        i.set_attr "type", fwsMor.vimType
      end
      message.add "n1:id", rskey
    end
    (parse_response(response, 'EnableRulesetResponse'))
  end

  def enterMaintenanceMode_Task(hMor, timeout = 0, evacuatePoweredOffVms = false)
    response = invoke("n1:EnterMaintenanceMode_Task") do |message|
      message.add "n1:_this", hMor do |i|
        i.set_attr "type", hMor.vimType
      end
      message.add "n1:timeout", timeout.to_s
      message.add "n1:evacuatePoweredOffVms", evacuatePoweredOffVms.to_s
    end
    (parse_response(response, 'EnterMaintenanceMode_TaskResponse'))['returnval']
  end

  def exitMaintenanceMode_Task(hMor, timeout = 0)
    response = invoke("n1:ExitMaintenanceMode_Task") do |message|
      message.add "n1:_this", hMor do |i|
        i.set_attr "type", hMor.vimType
      end
      message.add "n1:timeout", timeout.to_s
    end
    (parse_response(response, 'ExitMaintenanceMode_TaskResponse'))['returnval']
  end

  def getAlarm(alarmManager, mor)
    response = invoke("n1:GetAlarm") do |message|
      message.add "n1:_this", alarmManager do |i|
        i.set_attr "type", alarmManager.vimType
      end
      message.add "n1:entity", mor do |i|
        i.set_attr "type", mor.vimType
      end if mor
    end
    (parse_response(response, 'GetAlarmResponse')['returnval'])
  end

  def getCustomizationSpec(csmMor, name)
    csmMor.GetCustomizationSpec(:name => name)
  end

  def login(sessionManager, username, password)
    session_manager = vim_to_rbvmomi_types(sessionManager)
    session_manager.Login(:userName => username, :password => password)
  end

  def logout(sessionManager)
    session_manager = vim_to_rbvmomi_types(sessionManager)
    session_manager.Logout
  end

  def logUserEvent(eventManager, entity, msg)
    response = invoke("n1:LogUserEvent") do |message|
      message.add "n1:_this", eventManager do |i|
        i.set_attr "type", eventManager.vimType
      end
      message.add "n1:entity", entity do |i|
        i.set_attr "type", entity.vimType
      end
      message.add "n1:msg", msg
    end
    (parse_response(response, 'LogUserEventResponse'))
  end

  def markAsTemplate(vmMor)
    response = invoke("n1:MarkAsTemplate") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'MarkAsTemplateResponse'))
  end

  def markAsVirtualMachine(vmMor, pmor, hmor = nil)
    response = invoke("n1:MarkAsVirtualMachine") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
      message.add "n1:pool", pmor do |i|
        i.set_attr "type", pmor.vimType
      end
      message.add "n1:host", hmor do |i|
        i.set_attr "type", hmor.vimType
      end if hmor
    end
    (parse_response(response, 'MarkAsVirtualMachineResponse'))
  end

  def migrateVM_Task(vmMor, pmor = nil, hmor = nil, priority = "defaultPriority", state = nil)
    response = invoke("n1:MigrateVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
      message.add "n1:pool", pmor do |i|
        i.set_attr "type", pmor.vimType
      end if pmor
      message.add "n1:host", hmor do |i|
        i.set_attr "type", hmor.vimType
      end if hmor
      message.add "n1:priority", priority
      message.add "n1:state", state if state
    end
    (parse_response(response, 'MigrateVM_TaskResponse')['returnval'])
  end

  def moveIntoFolder_Task(fMor, oMor)
    response = invoke("n1:MoveIntoFolder_Task") do |message|
      message.add "n1:_this", fMor do |i|
        i.set_attr "type", fMor.vimType
      end
      message.add "n1:list", oMor do |i|
        i.set_attr "type", oMor.vimType
      end
    end
    parse_response(response, 'MoveIntoFolder_TaskResponse')['returnval']
  end

  def relocateVM_Task(vmMor, cspec, priority = "defaultPriority")
    response = invoke("n1:RelocateVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", cspec.xsiType
        marshalObj(i, cspec)
      end
      message.add "n1:priority", priority
    end
    (parse_response(response, 'RelocateVM_TaskResponse')['returnval'])
  end

  def powerDownHostToStandBy_Task(hMor, timeoutSec = 0, evacuatePoweredOffVms = false)
    response = invoke("n1:PowerDownHostToStandBy_Task") do |message|
      message.add "n1:_this", hMor do |i|
        i.set_attr "type", hMor.vimType
      end
      message.add "n1:timeoutSec", timeoutSec.to_s
      message.add "n1:evacuatePoweredOffVms", evacuatePoweredOffVms.to_s
    end
    (parse_response(response, 'PowerDownHostToStandBy_TaskResponse'))['returnval']
  end

  def powerOffVM_Task(vmMor)
    response = invoke("n1:PowerOffVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'PowerOffVM_TaskResponse')['returnval'])
  end

  def powerOnVM_Task(vmMor)
    response = invoke("n1:PowerOnVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'PowerOnVM_TaskResponse')['returnval'])
  end

  def powerUpHostFromStandBy_Task(hMor, timeoutSec = 0)
    response = invoke("n1:PowerUpHostFromStandBy_Task") do |message|
      message.add "n1:_this", hMor do |i|
        i.set_attr "type", hMor.vimType
      end
      message.add "n1:timeoutSec", timeoutSec.to_s
    end
    (parse_response(response, 'PowerUpHostFromStandBy_TaskResponse'))['returnval']
  end

  def queryAvailablePerfMetric(perfManager, entity, beginTime = nil, endTime = nil, intervalId = nil)
    response = invoke("n1:QueryAvailablePerfMetric") do |message|
      message.add "n1:_this", perfManager do |i|
        i.set_attr "type", perfManager.vimType
      end
      message.add "n1:entity", entity do |i|
        i.set_attr "type", entity.vimType
      end
      message.add "n1:beginTime", beginTime.to_s  if beginTime
      message.add "n1:endTime", endTime.to_s    if endTime
      message.add "n1:intervalId", intervalId   if intervalId
    end
    (parse_response(response, 'QueryAvailablePerfMetricResponse')['returnval'])
  end

  def queryDescriptions(diagnosticManager, entity)
    response = invoke("n1:QueryDescriptions") do |message|
      message.add "n1:_this", diagnosticManager do |i|
        i.set_attr "type", diagnosticManager.vimType
      end
      message.add "n1:host", entity do |i|
        i.set_attr "type", entity.vimType
      end if entity
    end
    (parse_response(response, 'QueryDescriptionsResponse')['returnval'])
  end

  def queryDvsConfigTarget(dvsManager, hmor, _dvs)
    response = invoke("n1:QueryDvsConfigTarget") do |message|
      message.add "n1:_this", dvsManager do |i|
        i.set_attr "type", dvsManager.vimType
      end
      message.add "n1:host", hmor do |i|
        i.set_attr "type", hmor.vimType
      end if hmor
    end
    (parse_response(response, 'QueryDvsConfigTargetResponse')['returnval'])
    # TODO: dvs
  end

  def queryNetConfig(vnmMor, nicType)
    response = invoke("n1:QueryNetConfig") do |message|
      message.add "n1:_this", vnmMor do |i|
        i.set_attr "type", vnmMor.vimType
      end
      message.add "n1:nicType", nicType
    end
    (parse_response(response, 'QueryNetConfigResponse')['returnval'])
  end

  def queryOptions(omMor, name)
    response = invoke("n1:QueryOptions") do |message|
      message.add "n1:_this", omMor do |i|
        i.set_attr "type", omMor.vimType
      end
      message.add "n1:name", name
    end
    (parse_response(response, 'QueryOptionsResponse')['returnval'])
  end

  def queryPerf(perfManager, querySpec)
    response = invoke("n1:QueryPerf") do |message|
      message.add "n1:_this", perfManager do |i|
        i.set_attr "type", perfManager.vimType
      end
      if querySpec.kind_of?(Array)
        querySpec.each do |qs|
          message.add "n1:querySpec" do |i|
            i.set_attr "xsi:type", qs.xsiType
            marshalObj(i, qs)
          end
        end
      else
        message.add "n1:querySpec" do |i|
          i.set_attr "xsi:type", querySpec.xsiType
          marshalObj(i, querySpec)
        end
      end
    end
    (parse_response(response, 'QueryPerfResponse')['returnval'])
  end

  def queryPerfComposite(perfManager, querySpec)
    response = invoke("n1:QueryPerfComposite") do |message|
      message.add "n1:_this", perfManager do |i|
        i.set_attr "type", perfManager.vimType
      end
      message.add "n1:querySpec" do |i|
        i.set_attr "xsi:type", querySpec.xsiType
        marshalObj(i, querySpec)
      end
    end
    (parse_response(response, 'QueryPerfCompositeResponse')['returnval'])
  end

  def queryPerfProviderSummary(perfManager, entity)
    response = invoke("n1:QueryPerfProviderSummary") do |message|
      message.add "n1:_this", perfManager do |i|
        i.set_attr "type", perfManager.vimType
      end
      message.add "n1:entity", entity do |i|
        i.set_attr "type", entity.vimType
      end
    end
    (parse_response(response, 'QueryPerfProviderSummaryResponse')['returnval'])
  end

  def readNextEvents(ehcMor, maxCount)
    response = invoke("n1:ReadNextEvents") do |message|
      message.add "n1:_this", ehcMor do |i|
        i.set_attr "type", ehcMor.vimType
      end
      message.add "n1:maxCount", maxCount
    end
    (parse_response(response, 'ReadNextEventsResponse')['returnval'])
  end

  def readPreviousEvents(ehcMor, maxCount)
    response = invoke("n1:ReadPreviousEvents") do |message|
      message.add "n1:_this", ehcMor do |i|
        i.set_attr "type", ehcMor.vimType
      end
      message.add "n1:maxCount", maxCount
    end
    (parse_response(response, 'ReadPreviousEventsResponse')['returnval'])
  end

  def rebootGuest(vmMor)
    response = invoke("n1:RebootGuest") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'RebootGuestResponse'))
  end

  def rebootHost_Task(hMor, force = false)
    response = invoke("n1:RebootHost_Task") do |message|
      message.add "n1:_this", hMor do |i|
        i.set_attr "type", hMor.vimType
      end
      message.add "n1:force", force.to_s
    end
    (parse_response(response, 'RebootHost_TaskResponse'))['returnval']
  end

  def reconfigureAlarm(aMor, aSpec)
    response = invoke("n1:ReconfigureAlarm") do |message|
      message.add "n1:_this", aMor do |i|
        i.set_attr "type", aMor.vimType
      end
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", aSpec.xsiType
        marshalObj(i, aSpec)
      end
    end
    (parse_response(response, 'ReconfigureAlarmResponse'))
  end

  def reconfigVM_Task(vmMor, vmConfigSpec)
    response = invoke("n1:ReconfigVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
      message.add "n1:spec" do |i|
        i.set_attr "xsi:type", vmConfigSpec.xsiType
        marshalObj(i, vmConfigSpec)
      end
    end
    (parse_response(response, 'ReconfigVM_TaskResponse')['returnval'])
  end

  def refreshFirewall(fwsMor)
    response = invoke("n1:RefreshFirewall") do |message|
      message.add "n1:_this", fwsMor do |i|
        i.set_attr "type", fwsMor.vimType
      end
    end
    (parse_response(response, 'RefreshFirewallResponse'))
  end

  def refreshNetworkSystem(nsMor)
    response = invoke("n1:RefreshNetworkSystem") do |message|
      message.add "n1:_this", nsMor do |i|
        i.set_attr "type", nsMor.vimType
      end
    end
    (parse_response(response, 'RefreshNetworkSystemResponse'))
  end

  def refreshServices(ssMor)
    response = invoke("n1:RefreshServices") do |message|
      message.add "n1:_this", ssMor do |i|
        i.set_attr "type", ssMor.vimType
      end
    end
    (parse_response(response, 'RefreshServicesResponse'))
  end

  def registerVM_Task(fMor, path, name, asTemplate, pmor, hmor)
    response = invoke("n1:RegisterVM_Task") do |message|
      message.add "n1:_this", fMor do |i|
        i.set_attr "type", fMor.vimType
      end
      message.add "n1:path", path
      message.add "n1:name", name if name
      message.add "n1:asTemplate", asTemplate
      message.add "n1:pool", pmor do |i|
        i.set_attr "type", pmor.vimType
      end if pmor
      message.add "n1:host", hmor do |i|
        i.set_attr "type", hmor.vimType
      end if hmor
    end
    (parse_response(response, 'RegisterVM_TaskResponse')['returnval'])
  end

  def removeAlarm(aMor)
    response = invoke("n1:RemoveAlarm") do |message|
      message.add "n1:_this", aMor do |i|
        i.set_attr "type", aMor.vimType
      end
    end
    (parse_response(response, 'RemoveAlarmResponse'))
  end

  def removeAllSnapshots_Task(vmMor)
    response = invoke("n1:RemoveAllSnapshots_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'RemoveAllSnapshots_TaskResponse')['returnval'])
  end

  def removeSnapshot_Task(snMor, subTree)
    response = invoke("n1:RemoveSnapshot_Task") do |message|
      message.add "n1:_this", snMor do |i|
        i.set_attr "type", snMor.vimType
      end
      message.add "n1:removeChildren", subTree
    end
    (parse_response(response, 'RemoveSnapshot_TaskResponse')['returnval'])
  end

  def rename_Task(vmMor, newName)
    response = invoke("n1:Rename_Task") do |message|
      message.add("n1:_this", vmMor) do |i|
        i.set_attr("type", vmMor.vimType)
      end
      message.add("n1:newName", newName)
    end
    parse_response(response, 'Rename_TaskResponse')['returnval']
  end

  def renameSnapshot(snMor, name, desc)
    response = invoke("n1:RenameSnapshot") do |message|
      message.add "n1:_this", snMor do |i|
        i.set_attr "type", snMor.vimType
      end
      message.add "n1:name", name if name
      message.add "n1:description", desc if desc
    end
    (parse_response(response, 'RenameSnapshotResponse'))
  end

  def resetCollector(collectorMor)
    response = invoke("n1:ResetCollector") do |message|
      message.add "n1:_this", collectorMor do |i|
        i.set_attr "type", collectorMor.vimType
      end
    end
    (parse_response(response, 'ResetCollectorResponse'))
  end

  def resetVM_Task(vmMor)
    response = invoke("n1:ResetVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'ResetVM_TaskResponse')['returnval'])
  end

  def restartService(ssMor, skey)
    response = invoke("n1:RestartService") do |message|
      message.add "n1:_this", ssMor do |i|
        i.set_attr "type", ssMor.vimType
      end
      message.add "n1:id", skey
    end
    (parse_response(response, 'RestartServiceResponse'))
  end

  def retrieveProperties(propCol, specSet)
    response = invoke("n1:RetrieveProperties") do |message|
      message.add "n1:_this", propCol do |i|
        i.set_attr "type", propCol.vimType
      end
      message.add "n1:specSet" do |i|
        i.set_attr "xsi:type", "PropertyFilterSpec"
        marshalObj(i, specSet)
      end
    end
    (parse_response(response, 'RetrievePropertiesResponse')['returnval'])
  end

  def retrievePropertiesEx(propCol, specSet, max_objects = nil)
    options = VimHash.new("RetrieveOptions") do |opts|
      opts.maxObjects = max_objects.to_s if max_objects
    end

    response = invoke("n1:RetrievePropertiesEx") do |message|
      message.add "n1:_this", propCol do |i|
        i.set_attr "type", propCol.vimType
      end
      message.add "n1:specSet" do |i|
        i.set_attr "xsi:type", "PropertyFilterSpec"
        marshalObj(i, specSet)
      end
      message.add "n1:options" do |i|
        i.set_attr "xsi:type", "RetrieveOptions"
        marshalObj(i, options)
      end
    end
    (parse_response(response, 'RetrievePropertiesExResponse')['returnval'])
  end

  def retrievePropertiesIter(propCol, specSet, max_objects = nil)
    result = retrievePropertiesEx(propCol, specSet, max_objects)

    while result
      begin
        result['objects'].to_a.each { |oc| yield oc }
      rescue
        # if for some reason the caller breaks out of the block let the
        # server know we are going to cancel this retrievePropertiesEx call
        cancelRetrievePropertiesEx(propCol, result['token']) if result['token']
      end

      # if there is no token returned then all results fit in a single page
      # and we are done
      break if result['token'].nil?

      # there is more than one page of result so continue getting the rest
      result = continueRetrievePropertiesEx(propCol, result['token'])
    end
  end

  def retrievePropertiesCompat(propCol, specSet, max_objects = nil)
    objects = VimArray.new('ArrayOfObjectContent')

    retrievePropertiesIter(propCol, specSet, max_objects) { |oc| objects << oc }

    objects
  end

  def retrieveServiceContent
    rbvmomi_to_vim_types(vim.serviceContent)
  end

  def revertToCurrentSnapshot_Task(vmMor)
    response = invoke("n1:RevertToCurrentSnapshot_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'RevertToCurrentSnapshot_TaskResponse')['returnval'])
  end

  def revertToSnapshot_Task(snMor)
    response = invoke("n1:RevertToSnapshot_Task") do |message|
      message.add "n1:_this", snMor do |i|
        i.set_attr "type", snMor.vimType
      end
    end
    (parse_response(response, 'RevertToSnapshot_TaskResponse')['returnval'])
  end

  def rewindCollector(collectorMor)
    response = invoke("n1:RewindCollector") do |message|
      message.add "n1:_this", collectorMor do |i|
        i.set_attr "type", collectorMor.vimType
      end
    end
    (parse_response(response, 'RewindCollectorResponse'))
  end

  def searchDatastore_Task(browserMor, dsPath, searchSpec)
    response = invoke("n1:SearchDatastore_Task") do |message|
      message.add "n1:_this", browserMor do |i|
        i.set_attr "type", browserMor.vimType
      end
      message.add "n1:datastorePath", dsPath
      message.add "n1:searchSpec" do |i|
        i.set_attr "xsi:type", searchSpec.xsiType
        marshalObj(i, searchSpec)
      end if searchSpec
    end
    (parse_response(response, 'SearchDatastore_TaskResponse')['returnval'])
  end

  def searchDatastoreSubFolders_Task(browserMor, dsPath, searchSpec)
    response = invoke("n1:SearchDatastoreSubFolders_Task") do |message|
      message.add "n1:_this", browserMor do |i|
        i.set_attr "type", browserMor.vimType
      end
      message.add "n1:datastorePath", dsPath
      message.add "n1:searchSpec" do |i|
        i.set_attr "xsi:type", searchSpec.xsiType
        marshalObj(i, searchSpec)
      end if searchSpec
    end
    (parse_response(response, 'SearchDatastoreSubFolders_TaskResponse')['returnval'])
  end

  def selectVnicForNicType(vnmMor, nicType, device)
    response = invoke("n1:SelectVnicForNicType") do |message|
      message.add "n1:_this", vnmMor do |i|
        i.set_attr "type", vnmMor.vimType
      end
      message.add "n1:nicType", nicType
      message.add "n1:device", device
    end
    (parse_response(response, 'SelectVnicForNicTypeResponse'))
  end

  def setCollectorPageSize(collector, maxCount)
    response = invoke("n1:SetCollectorPageSize") do |message|
      message.add "n1:_this", collector do |i|
        i.set_attr "type", collector.vimType
      end
      message.add "n1:maxCount", maxCount
    end
    (parse_response(response, 'SetCollectorPageSizeResponse'))
  end

  def setField(cfManager, mor, key, value)
    response = invoke("n1:SetField") do |message|
      message.add "n1:_this", cfManager do |i|
        i.set_attr "type", cfManager.vimType
      end
      message.add "n1:entity", mor do |i|
        i.set_attr "type", mor.vimType
      end
      message.add "n1:key", key
      message.add "n1:value", value
    end
    (parse_response(response, 'SetFieldResponse'))
  end

  def setTaskDescription(tmor, description)
    response = invoke("n1:SetTaskDescription") do |message|
      message.add "n1:_this", tmor do |i|
        i.set_attr "type", tmor.vimType
      end
      message.add "n1:description" do |i|
        i.set_attr "xsi:type", description.xsiType
        marshalObj(i, description)
      end
    end
    (parse_response(response, 'SetTaskDescriptionResponse'))
  end

  def setTaskState(tmor, state, result = nil, fault = nil)
    response = invoke("n1:SetTaskState") do |message|
      message.add "n1:_this", tmor do |i|
        i.set_attr "type", tmor.vimType
      end
      message.add "n1:state", state do |i|
        i.set_attr "xsi:type", "TaskInfoState"
      end
      message.add "n1:result" do |i|
        i.set_attr "xsi:type", result.xsiType
        marshalObj(i, result)
      end if result
      message.add "n1:fault" do |i|
        i.set_attr "xsi:type", fault.xsiType
        marshalObj(i, fault)
      end if fault
    end
    (parse_response(response, 'SetTaskStateResponse'))
  end

  def shutdownGuest(vmMor)
    response = invoke("n1:ShutdownGuest") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'ShutdownGuestResponse'))
  end

  def shutdownHost_Task(hMor, force = false)
    response = invoke("n1:ShutdownHost_Task") do |message|
      message.add "n1:_this", hMor do |i|
        i.set_attr "type", hMor.vimType
      end
      message.add "n1:force", force.to_s
    end
    (parse_response(response, 'ShutdownHost_TaskResponse'))['returnval']
  end

  def standbyGuest(vmMor)
    response = invoke("n1:StandbyGuest") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'StandbyGuestResponse'))
  end

  def startService(ssMor, skey)
    response = invoke("n1:StartService") do |message|
      message.add "n1:_this", ssMor do |i|
        i.set_attr "type", ssMor.vimType
      end
      message.add "n1:id", skey
    end
    (parse_response(response, 'StartServiceResponse'))
  end

  def stopService(ssMor, skey)
    response = invoke("n1:StopService") do |message|
      message.add "n1:_this", ssMor do |i|
        i.set_attr "type", ssMor.vimType
      end
      message.add "n1:id", skey
    end
    (parse_response(response, 'StopServiceResponse'))
  end

  def suspendVM_Task(vmMor)
    response = invoke("n1:SuspendVM_Task") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'SuspendVM_TaskResponse')['returnval'])
  end

  def uninstallService(ssMor, skey)
    response = invoke("n1:UninstallService") do |message|
      message.add "n1:_this", ssMor do |i|
        i.set_attr "type", ssMor.vimType
      end
      message.add "n1:id", skey
    end
    (parse_response(response, 'UninstallServiceResponse'))
  end

  def unregisterVM(vmMor)
    response = invoke("n1:UnregisterVM") do |message|
      message.add "n1:_this", vmMor do |i|
        i.set_attr "type", vmMor.vimType
      end
    end
    (parse_response(response, 'UnregisterVMResponse'))
  end

  def updateDefaultPolicy(fwsMor, defaultPolicy)
    response = invoke("n1:UpdateDefaultPolicy") do |message|
      message.add "n1:_this", fwsMor do |i|
        i.set_attr "type", fwsMor.vimType
      end
      message.add "n1:defaultPolicy" do |i|
        i.set_attr "xsi:type", defaultPolicy.xsiType
        marshalObj(i, defaultPolicy)
      end
    end
    (parse_response(response, 'UpdateDefaultPolicyResponse'))
  end

  def updateServicePolicy(sMor, skey, policy)
    response = invoke("n1:UpdateServicePolicy") do |message|
      message.add "n1:_this", sMor do |i|
        i.set_attr "type", sMor.vimType
      end
      message.add "n1:id", skey
      message.add "n1:policy", policy
    end
    (parse_response(response, 'UpdateServicePolicyResponse'))
  end

  def updateSoftwareInternetScsiEnabled(hssMor, enabled)
    response = invoke("n1:UpdateSoftwareInternetScsiEnabled") do |message|
      message.add "n1:_this", hssMor do |i|
        i.set_attr "type", hssMor.vimType
      end
      message.add "n1:enabled", enabled.to_s
    end
    (parse_response(response, 'UpdateSoftwareInternetScsiEnabledResponse'))
  end

  def waitForUpdates(property_collector, version = nil)
    rbvmomi_to_vim_types(vim_to_rbvmomi_types(property_collector).WaitForUpdates(:version => version))
  end

  def waitForUpdatesEx(property_collector, version = nil, options = {})
    options  = RbVmomi::VIM.WaitOptions(:maxObjectUpdates => options[:max_objects], :maxWaitSeconds => options[:max_wait])
    response = vim_to_rbvmomi_types(property_collector).WaitForUpdatesEx(:version => version, :options => options)
    rbvmomi_to_vim_types(response)
  end

  def xmlToCustomizationSpecItem(csmMor, specItemXml)
    response = invoke("n1:XmlToCustomizationSpecItem") do |message|
      message.add "n1:_this", csmMor do |i|
        i.set_attr "type", csmMor.vimType
      end
      message.add "n1:specItemXml", specItemXml
    end
    (parse_response(response, 'XmlToCustomizationSpecItemResponse')['returnval'])
  end

  private

  def rbvmomi_to_vim_types(obj)
    case obj
    when Array
      obj.map { |i| rbvmomi_to_vim_types(i) }
    when RbVmomi::BasicTypes::ManagedObject
      VimString.new(obj._ref, obj.class.wsdl_name, :ManagedObjectReference)
    when RbVmomi::BasicTypes::Base
      VimHash.new(obj.class.wsdl_name).tap do |vim|
        obj.props.each do |key, val|
          vim.send("#{key}=", rbvmomi_to_vim_types(val))
        end
      end
    when String, Symbol, Integer, Time, TrueClass, FalseClass, NillClass
      obj
    else
      raise ArgumentError, "Invalid type #{obj.class}"
    end
  end

  def vim_to_rbvmomi_types(obj)
    case obj
    when Array
      obj.map { |i| vim_to_rbvmomi_types(i) }
    when VimHash
      klass = RbVmomi::VIM.const_get(obj.xsiType)
      klass.new.tap do |new_obj|
        obj.each do |key, val|
          new_obj.send("#{key}=", vim_to_rbvmomi_types(val))
        end
      end
    when VimString
      if obj.xsiType == "ManagedObjectReference"
        klass = RbVmomi::VIM.const_get(obj.xsiType)
        klass.new(vim, obj.to_s)
      else
        obj.to_s
      end
    when String, Symbol, Integer, Time, TrueClass, FalseClass, NillClass
      obj
    else
      raise ArgumentError, "Invalid type #{obj.class}"
    end
  end
end
