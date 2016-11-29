module MiqVimObjectSet
  #
  # Construct an ObjectSpec to traverse the entire VI inventory tree.
  #
  def objectSet
    #
    # Traverse VirtualApp to Vm.
    #
    virtualAppTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "virtualAppTraversalSpec"
      ts.type = "VirtualApp"
      ts.path = "vm"
      ts.skip = "false"
    end unless @v2

    #
    # Traverse ResourcePool to ResourcePool and VirtualApp.
    #
    resourcePoolTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "resourcePoolTraversalSpec"
      ts.type      = "ResourcePool"
      ts.path      = "resourcePool"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "resourcePoolTraversalSpec" }
      end
    end

    #
    # Traverse ComputeResource to ResourcePool.
    #
    computeResourceRpTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "computeResourceRpTraversalSpec"
      ts.type      = "ComputeResource"
      ts.path      = "resourcePool"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "resourcePoolTraversalSpec" }
      end
    end

    #
    # Traverse ComputeResource to host.
    #
    computeResourceHostTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "computeResourceHostTraversalSpec"
      ts.type = "ComputeResource"
      ts.path = "host"
      ts.skip = "false"
    end

    #
    # Traverse Datacenter to host folder.
    #
    datacenterHostTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "datacenterHostTraversalSpec"
      ts.type      = "Datacenter"
      ts.path      = "hostFolder"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Datacenter to VM folder.
    #
    datacenterVmTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "datacenterVmTraversalSpec"
      ts.type      = "Datacenter"
      ts.path      = "vmFolder"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Datacenter to Datastore folder.
    #
    datacenterDsFolderTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "dcTodf"
      ts.type      = "Datacenter"
      ts.path      = "datastoreFolder"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Datacenter to Datastore.
    #
    datacenterDsTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "datacenterDsTraversalSpec"
      ts.type = "Datacenter"
      ts.path = "datastore"
      ts.skip = "false"
    end

    #
    # Traverse Datacenter to Network folder
    #
    datacenterNetworkFolderTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "dcTonf"
      ts.type = "Datacenter"
      ts.path = "networkFolder"
      ts.skip = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Folder to children.
    #
    folderTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "folderTraversalSpec"
      ts.type      = "Folder"
      ts.path      = "childEntity"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
        ssa << datacenterHostTs
        ssa << datacenterVmTs
        ssa << datacenterDsTs
        ssa << datacenterDsFolderTs
        ssa << datacenterNetworkFolderTs
        ssa << computeResourceRpTs
        ssa << computeResourceHostTs
        ssa << resourcePoolTs
        ssa << virtualAppTs unless @v2
      end
    end

    aOobjSpec = VimArray.new("ArrayOfObjectSpec") do |osa|
      osa << VimHash.new("ObjectSpec") do |os|
        os.obj       = @sic.rootFolder
        os.skip      = "false"
        os.selectSet = VimArray.new("ArrayOfSelectionSpec") { |ssa| ssa << folderTs }
      end
    end

    (aOobjSpec)
  end # def objectSet
end
