module MiqVimUpdate
  @@max_retries = 4

  def debugUpdates=(val)
    @debugUpdates = val
    @dumpToLog = true if @debugUpdates
  end

  def notifyMethod=(val)
    @notifyMethod = val
  end

  def updateDelay=(val)
    @updateDelay = val
  end

  def updateDelay
    @updateDelay
  end

  def monitorUpdatesInitial(preLoad)
    log_prefix = "MiqVimUpdate.monitorUpdatesInitial (#{@connId})"

    version      = nil
    truncated    = true
    wait_options = {:max_objects => @maxObjects}

    while truncated
      begin
        logger.info "#{log_prefix}: call to waitForUpdates...Starting"
        updateSet = waitForUpdatesEx(@umPropCol, version, wait_options)
        logger.info "#{log_prefix}: call to waitForUpdates...Complete"

        version   = updateSet.version
        truncated = updateSet.truncated

        if preLoad && @monitor
          @cacheLock.synchronize(:EX) do
            updateSet.filterSet.each do |fu|
              next if fu.filter != @filterSpecRef
              fu.objectSet.each { |objUpdate| updateObject(objUpdate, true) }
            end # updateSet.filterSet.each
            iUpdateFixUp
          end
        end
        # Help out the Ruby Garbage Collector by resetting variables pointing to large objects back to nil
        updateSet = nil
      rescue HTTPClient::ReceiveTimeoutError => terr
        logger.info "#{log_prefix}: call to waitForUpdates...Timeout"
        raise terr if !isAlive?
        retry
      end
    end

    return version
  end

  def monitorUpdatesSince(version)
    log_prefix = "MiqVimUpdate.monitorUpdatesSince (#{@connId})"
    begin
      logger.info "#{log_prefix}: call to waitForUpdates...Starting (version = #{version})"
      updateSet = waitForUpdatesEx(@umPropCol, version, :max_wait => @maxWait)
      logger.info "#{log_prefix}: call to waitForUpdates...Complete (version = #{version})"
      return version if updateSet.nil?

      version = updateSet.version

      return if updateSet.filterSet.nil? || updateSet.filterSet.empty?

      updateSet.filterSet.each do |fu|
        next if fu.filter != @filterSpecRef
        fu.objectSet.each do |objUpdate|
          logger.info "#{log_prefix}: applying update...Starting (version = #{version})"
          @cacheLock.synchronize(:EX) do
            updateObject(objUpdate)
          end
          logger.info "#{log_prefix}: applying update...Complete (version = #{version})"
          Thread.pass
        end
      end # updateSet.filterSet.each
      # Help out the Ruby Garbage Collector by resetting variables pointing to large objects back to nil
      updateSet = nil
      return version
    rescue HTTPClient::ReceiveTimeoutError => terr
      logger.info "#{log_prefix}: call to waitForUpdates...Timeout (version = #{version})"
      retry if isAlive?
      logger.warn "#{log_prefix}: connection lost"
      raise terr
    end
  end

  def monitorUpdates(preLoad = false)
    log_prefix = "MiqVimUpdate.monitorUpdates (#{@connId})"
    @umPropCol      = nil
    @filterSpecRef  = nil
    @monitor        = true
    @debugUpdates   = false if @debugUpdates.nil?
    @dumpToLog      = true  if @debugUpdates

    logger.debug "#{log_prefix}: debugUpdates = #{@debugUpdates}"

    begin
      @umPropCol     = @sic.propertyCollector
      @filterSpecRef = createFilter(@umPropCol, @updateSpec, "true")

      version = monitorUpdatesInitial(preLoad)
      @updateMonitorReady = true

      while @monitor
        updates_version = monitorUpdatesSince(version)
        next if updates_version.nil?
        version = updates_version
        sleep @updateDelay if @updateDelay
      end # while @monitor
    rescue SignalException
      # Ignore signals, except TERM
    rescue => herr
      if herr.respond_to?(:reason) && herr.reason == 'The task was canceled by a user.'
        logger.info "#{log_prefix}: waitForUpdates canceled"
      else
        logger.error "******* #{herr.class}"
        logger.error herr.to_s
        logger.error herr.backtrace.join("\n") unless herr.kind_of?(HTTPClient::ReceiveTimeoutError) # already logged in monitorUpdatesInitial or monitorUpdatesSince
        raise herr
      end
    ensure
      if @filterSpecRef && isAlive?
        logger.info "#{log_prefix}: calling destroyPropertyFilter...Starting"
        destroyPropertyFilter(@filterSpecRef)
        logger.info "#{log_prefix}: calling destroyPropertyFilter...Complete"
      end
      @filterSpecRef = nil
      # @umPropCol     = nil
    end
  end # def monitorUpdates

  def stopUpdateMonitor
    log_prefix = "MiqVimUpdate.stopUpdateMonitor (#{@connId})"

    logger.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Starting"
    @monitor = false
    if @umPropCol
      if isAlive?
        logger.info "#{log_prefix}: calling cancelWaitForUpdates...Starting"
        cancelWaitForUpdates(@umPropCol)
        logger.info "#{log_prefix}: calling cancelWaitForUpdates...Complete"
      end
      @umPropCol = nil
      @updateThread.run if @updateThread.status == "sleep"
    end
    logger.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Complete"
  end

  def forceFail
    isDead
    cancelWaitForUpdates(@umPropCol) if @umPropCol
  end

  def updateObject(objUpdate, initialUpdate = false)
    unless @inventoryHash # no cache to update
      return unless initialUpdate
      logger.info "MiqVimUpdate.updateObject: setting @inventoryHash to empty hash"
      @inventoryHash = {}
    end

    case objUpdate.kind
    when 'enter'
      addObject(objUpdate, initialUpdate)
    when 'leave'
      deleteObject(objUpdate, initialUpdate)
    when 'modify'
      updateProps(objUpdate, initialUpdate)
    else
      logger.warn "MiqVimUpdate.updateObject (#{@connId}): unrecognized operation: #{objUpdate.kind}"
    end
  end

  def updateProps(objUpdate, initialUpdate = false)
    logger.debug "Update object (#{@connId}): #{objUpdate.obj.vimType}: #{objUpdate.obj}" if @debugUpdates
    return if !objUpdate.changeSet || objUpdate.changeSet.empty?

    #
    # Look up root hash of object in the <objType>ByMor hash and pass it
    # to the prop update routines: add, remove, assign.
    #
    objType = objUpdate.obj.vimBaseType.to_sym
    unless (pm = @propMap[objType])
      # We don't cache this type of object
      return
    end
    hashName = "#{pm[:baseName]}ByMor"
    return unless (objHash = instance_variable_get(hashName)) # no cache to update
    unless (obj = objHash[objUpdate.obj])
      logger.warn "updateProps (#{@connId}): object #{objUpdate.obj} not found in #{hashName}"
      return
    end

    begin
      #
      # Before updating the object's properties, save its initial key value.
      #
      keyPath   = pm[:keyPath]
      keyPath2  = pm[:keyPath2]
      key0    = keyPath ? obj.fetch_path(keyPath) : nil
      key0b   = keyPath2 ? obj.fetch_path(keyPath2) : nil

      changedProps = propUpdate(obj, objUpdate.changeSet, true)

      key1      = keyPath ? obj.fetch_path(keyPath) : nil

      #
      # If the property we use as a hash key has changed, re-hash the object.
      #
      if keyPath
        objHash = (key1 == key0) ? nil : instance_variable_get(pm[:baseName])
        unless objHash.nil?
          objHash.delete(key0)  if key0
          objHash.delete(key0b) if key0b # changes when key0 changes.
          objHash[key1] = obj   if key1
          # Gets hashed by keyPath2 in objFixUp().
        end
      end

      #
      # Add our local values to cache:
      #   VMs:             ['summary']['config']['vmLocalPathName']
      #                    ['summary']["runtime"]["hostName"]
      #                    snapshot ['ssMorHash']
      #   Resource Pools:  ['summary']['name']
      #
      objFixUp(objType, obj)

      #
      # Call the notify callback if enabled, defined and we are past the initial update
      #
      if @notifyMethod && !initialUpdate
        logger.debug "MiqVimUpdate.updateProps (#{@connId}): server = #{@server}, mor = (#{objUpdate.obj.vimType}, #{objUpdate.obj})"
        logger.debug "MiqVimUpdate.updateProps (#{@connId}): changedProps = [ #{changedProps.join(', ')} ]"
        Thread.new do
          @notifyMethod.call(:server       => @server,
                             :username     => @username,
                             :op           => 'update',
                             :objType      => objUpdate.obj.vimType,
                             :mor          => objUpdate.obj,
                             :changedProps => changedProps,
                             :changeSet    => objUpdate.changeSet,
                             :key          => key0,
                             :newKey       => key1
                            )
        end
      end

    rescue => err
      logger.warn "MiqVimUpdate::updateProps (#{@connId}): #{err}"
      logger.warn "Clearing cache for (#{@connId}): #{pm[:baseName]}"
      logger.debug err.backtrace.join("\n")
      dumpCache("#{pm[:baseName]}ByMor")

      instance_variable_set("#{pm[:baseName]}ByMor", nil)
      instance_variable_set(pm[:baseName], nil)
    end
  end

  def addObject(objUpdate, initialUpdate)
    objType     = objUpdate.obj.vimType
    objBaseType = objUpdate.obj.vimBaseType

    # always log additions to the inventory.
    logger.info "MiqVimUpdate.addObject (#{@connId}): #{objType}: #{objUpdate.obj}"
    return unless (pm = @propMap[objBaseType.to_sym])  # not an object type we cache
    logger.info "MiqVimUpdate.addObject (#{@connId}): Adding object #{objType}: #{objUpdate.obj}"

    #
    # First, add the object's MOR to the @inventoryHash entry for the object's type.
    #
    ia = @inventoryHash[objType] = [] unless (ia = @inventoryHash[objType])
    ia << objUpdate.obj unless ia.include? objUpdate.obj

    begin
      #
      # Then hash the object's properties in its type specific hash.
      #
      hashName = "#{pm[:baseName]}ByMor"
      unless instance_variable_get(hashName) # no cache to update
        return unless initialUpdate
        logger.info "MiqVimUpdate.addObject: setting #{hashName} and #{pm[:baseName]} to empty hash"
        instance_variable_set(hashName, {})
        instance_variable_set(pm[:baseName], {})
      end

      obj = VimHash.new
      obj['MOR'] = objUpdate.obj
      propUpdate(obj, objUpdate.changeSet)

      addObjHash(objBaseType.to_sym, obj)

      #
      # Call the notify callback if enabled, defined and we are past the initial update
      #
      if @notifyMethod && !initialUpdate
        logger.debug "MiqVimUpdate.addObject: server = #{@server}, mor = (#{objUpdate.obj.vimType}, #{objUpdate.obj})"
        Thread.new do
          @notifyMethod.call(:server   => @server,
                             :username => @username,
                             :op       => 'create',
                             :objType  => objUpdate.obj.vimType,
                             :mor      => objUpdate.obj
                            )
        end
      end

    rescue => err
      logger.warn "MiqVimUpdate::addObject: #{err}"
      logger.warn "Clearing cache for: #{pm[:baseName]}"
      logger.debug err.backtrace.join("\n")
      dumpCache("#{pm[:baseName]}ByMor")

      instance_variable_set("#{pm[:baseName]}ByMor", nil)
      instance_variable_set(pm[:baseName], nil)
    end
  end

  def deleteObject(objUpdate, initialUpdate = false)
    objType     = objUpdate.obj.vimType
    objBaseType = objUpdate.obj.vimBaseType

    # always log deletions from the inventory.
    logger.info "MiqVimUpdate.deleteObject (#{@connId}): #{objType}: #{objUpdate.obj}"
    return unless (pm = @propMap[objBaseType.to_sym])      # not an object type we cache
    logger.info "MiqVimUpdate.deleteObject (#{@connId}): Deleting object: #{objType}: #{objUpdate.obj}"

    ia = @inventoryHash[objType]
    ia.delete(objUpdate.obj)

    return unless instance_variable_get("#{pm[:baseName]}ByMor")  # no cache to update

    begin
      removeObjByMor(objUpdate.obj)

      #
      # Call the notify callback if enabled, defined and we are past the initial update
      #
      if @notifyMethod && !initialUpdate
        logger.debug "MiqVimUpdate.deleteObject: server = #{@server}, mor = (#{objUpdate.obj.vimType}, #{objUpdate.obj})"
        Thread.new do
          @notifyMethod.call(:server   => @server,
                             :username => @username,
                             :op       => 'delete',
                             :objType  => objUpdate.obj.vimType,
                             :mor      => objUpdate.obj
                            )
        end
      end

    rescue => err
      logger.warn "MiqVimUpdate::deleteObject: #{err}"
      logger.warn "Clearing cache for: #{pm[:baseName]}"
      logger.debug err.backtrace.join("\n")
      dumpCache("#{pm[:baseName]}ByMor")

      instance_variable_set("#{pm[:baseName]}ByMor", nil)
      instance_variable_set(pm[:baseName], nil)
    end
  end

  def propUpdate(propHash, changeSet, returnChangedProps = false)
    changedProps = [] if returnChangedProps
    changeSet.each do |propChange|
      if @debugUpdates
        logger.debug "\tpropChange name (path): #{propChange.name}"
        logger.debug "\tpropChange op: #{propChange.op}"
        logger.debug "\tpropChange val (type): #{propChange.val.class}"

        logger.debug "\t*** propChange val START:"
        oGi = @globalIndent
        @globalIndent = "\t\t"
        dumpObj(propChange.val)
        @globalIndent = oGi
        logger.debug "\t*** propChange val END"
        logger.debug "\t***"
      end

      #
      # h is the parent hash of the property we're dealing with.
      # tag is the property name relative to the parent hash.
      # key identifies a specific array element, when the property is in an array.
      #
      h, propStr = hashTarget(propHash, propChange.name, true)
      tag, key   = tagAndKey(propStr)

      case propChange.op
      #
      # Add new entry into a collection (array)
      #
      when 'add'
        addToCollection(h, tag, propChange.val)
      #
      # Remove the property
      #
      when /remove|indirectRemove/
        if key
          # The property is an element in an array
          a, i = getVimArrayEnt(h[tag], key)
          a.delete_at(i)
        else
          h.delete(tag)
        end
      #
      # Assign a new value to the property
      #
      when 'assign'
        if key
          # The property is an element in an array
          a, i = getVimArrayEnt(h[tag], key, true)
          a[i] = propChange.val
        else
          h[tag] = propChange.val
        end
      end
      changedProps << propChange.name if returnChangedProps
    end
    return changedProps if returnChangedProps
  end

  def dumpCache(cache)
    return unless @debugUpdates
    logger.debug "**** Dumping #{cache} cache"
    dumbObj(instance_variable_get(cache))
    logger.debug "**** #{cache} dump end"
  end
  private :dumpCache

  def iUpdateFixUp
    @virtualMachinesByMor.each_value do |vm|
      unless vm['summary']['config']['vmLocalPathName']
        dsPath    = vm['summary']['config']['vmPathName']
        localPath = localVmPath(dsPath)
        vm['summary']['config']['vmLocalPathName'] = localPath
        @virtualMachines[localPath] = vm if localPath
      end
    end if @virtualMachinesByMor
  end
  private :iUpdateFixUp
end # module MiqVimUpdate
