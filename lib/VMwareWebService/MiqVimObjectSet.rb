module MiqVimObjectSet
  #
  # Construct an ObjectSpec to traverse the entire VI inventory tree.
  #
  def objectSet
    #
    # Traverse VirtualApp to Vm.
    #
    virtualAppTs = unless @v2
      RbVmomi::VIM::TraversalSpec(
       :name => "virtualAppTraversalSpec",
       :type => "VirtualApp",
       :path => "vm",
       :skip => false,
      )
    end

    #
    # Traverse ResourcePool to ResourcePool and VirtualApp.
    #
    resourcePoolTs = RbVmomi::VIM::TraversalSpec(
      :name      => "resourcePoolTraversalSpec",
      :type      => "ResourcePool",
      :path      => "resourcePool",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "resourcePoolTraversalSpec"),
      ],
    )

    #
    # Traverse ComputeResource to ResourcePool.
    #
    computeResourceRpTs = RbVmomi::VIM::TraversalSpec(
      :name      => "computeResourceRpTraversalSpec",
      :type      => "ComputeResource",
      :path      => "resourcePool",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "resourcePoolTraversalSpec"),
      ],
    )

    #
    # Traverse ComputeResource to host.
    #
    computeResourceHostTs = RbVmomi::VIM::TraversalSpec(
      :name => "computeResourceHostTraversalSpec",
      :type => "ComputeResource",
      :path => "host",
      :skip => false,
    )

    #
    # Traverse Datacenter to host folder.
    #
    datacenterHostTs = RbVmomi::VIM::TraversalSpec(
      :name      => "datacenterHostTraversalSpec",
      :type      => "Datacenter",
      :path      => "hostFolder",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "folderTraversalSpec"),
      ],
    )

    #
    # Traverse Datacenter to VM folder.
    #
    datacenterVmTs = RbVmomi::VIM::TraversalSpec(
      :name      => "datacenterVmTraversalSpec",
      :type      => "Datacenter",
      :path      => "vmFolder",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "folderTraversalSpec"),
      ],
    )

    #
    # Traverse Datacenter to Datastore folder.
    #
    datacenterDsFolderTs = RbVmomi::VIM::TraversalSpec(
      :name      => "dcTodf",
      :type      => "Datacenter",
      :path      => "datastoreFolder",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "folderTraversalSpec"),
      ],
    )

    #
    # Traverse Datacenter to Datastore.
    #
    datacenterDsTs = RbVmomi::VIM::TraversalSpec(
      :name => "datacenterDsTraversalSpec",
      :type => "Datacenter",
      :path => "datastore",
      :skip => false,
    )

    #
    # Traverse Datacenter to Network folder
    #
    datacenterNetworkFolderTs = RbVmomi::VIM::TraversalSpec(
      :name      => "dcTonf",
      :type      => "Datacenter",
      :path      => "networkFolder",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "folderTraversalSpec"),
      ],
    )

    #
    # Traverse Folder to children.
    #
    folderTs = RbVmomi::VIM::TraversalSpec(
      :name      => "folderTraversalSpec",
      :type      => "Folder",
      :path      => "childEntity",
      :skip      => false,
      :selectSet => [
        RbVmomi::VIM::SelectionSpec(:name => "folderTraversalSpec"),
        datacenterHostTs,
        datacenterVmTs,
        datacenterDsTs,
        datacenterDsFolderTs,
        datacenterNetworkFolderTs,
        computeResourceRpTs,
        computeResourceHostTs,
        resourcePoolTs,
        virtualAppTs,
      ],
    )

    [
      RbVmomi::VIM::ObjectSpec(:obj => @sic.rootFolder, :skip => false, :selectSet => [folderTs])
    ]
  end # def objectSet
end
