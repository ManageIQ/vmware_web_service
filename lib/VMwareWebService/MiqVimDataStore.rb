require 'sync'
require 'util/miq-extensions'  # Required patch to open-uri for get_file_content
require 'VMwareWebService/logging'

class MiqVimDataStore
  include VMwareWebService::Logging

  attr_reader :accessible, :multipleHostAccess, :name, :dsType, :url, :freeBytes, :capacityBytes, :uncommitted, :invObj

  def initialize(invObj, dsh)
    @invObj                 = invObj
    @sic                    = invObj.sic
    @dsh                    = dsh

    @accessible             = (@dsh['summary']['accessible'] == 'true')
    @multipleHostAccess     = (@dsh['summary']['multipleHostAccess'] == 'true')
    @name                   = @dsh['summary']['name']
    @dsType                 = @dsh['summary']['type']
    @url                    = @dsh['summary']['url']
    @dsMor                  = @dsh['summary']['datastore']
    @freeBytes              = @dsh['summary']['freeSpace'].to_i
    @capacityBytes          = @dsh['summary']['capacity'].to_i
    @uncommitted      = @dsh['summary']['uncommitted'].to_i if @invObj.apiVersion[0, 1].to_i <= 4 && @dsh['summary']['uncommitted']

    @browser                = nil
    @dsHash                 = nil

    @cacheLock              = Sync.new
  end

  #
  # Called when client is finished using this MiqVimVm object.
  # The server will delete its reference to the object, so the
  # server-side object csn be GC'd
  #
  def release
    # @invObj.releaseObj(self)
  end

  def dsMor
    (@dsMor)
  end

  def dsh
    (@dsh)
  end

  def browser_locked
    raise "browser_locked: cache lock not held" unless @cacheLock.sync_locked?
    return @browser if @browser

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      props = @invObj.getMoProp_local(@dsMor, "browser")
      @browser = props["browser"] if props
    ensure
      @cacheLock.sync_unlock if unlock
    end
    @browser
  end

  #
  # Public accessor
  #
  def browser
    @cacheLock.synchronize(:SH) do
      return(browser_locked)
    end
  end

  def dsFloppyImageFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('FloppyImageFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsFolderFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('FolderFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsIsoImageFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('IsoImageFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsVmDiskFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('VmDiskFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsVmLogFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('VmLogFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsVmNvramFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('VmNvramFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsVmSnapshotFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('VmSnapshotFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsVmConfigFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    dsSearch('VmConfigFileQuery', pattern, path, pathOnly, recurse)
  end

  def dsFileSearch(pattern = nil, path = nil, pathOnly = true, recurse = true)
    return(dsSearch(nil, pattern, path, pathOnly, recurse)) if @invObj.v20
    (dsSearch('FileQuery', pattern, path, pathOnly, recurse))
  end

  def dsSearch(typeClass, pattern = nil, path = nil, pathOnly = true, recurse = true)
    searchSpec = VimHash.new("HostDatastoreBrowserSearchSpec") do |hdbs|
      hdbs.details = VimHash.new("FileQueryFlags") do |fqf|
        fqf.fileSize    = "true"
        fqf.fileType    = "true"
        fqf.modification  = "true"
        fqf.fileOwner   = "true"
      end
      hdbs.query = VimArray.new("ArrayOfFileQuery") do |fqa|
        fqa << VimHash.new(typeClass)
      end if typeClass
      hdbs.matchPattern = pattern if pattern
      hdbs.sortFoldersFirst = "true"
    end

    browserMor = nil
    @cacheLock.synchronize(:SH) do
      browserMor = browser_locked
    end
    dsPath = "[#{@name}]"
    dsPath = "#{dsPath} #{path}" if path

    taskMor = nil
    if recurse
      logger.info "MiqVimDataStore(#{@invObj.server}, #{@invObj.username}).dsSearch: calling searchDatastoreSubFolders_Task"
      taskMor = @invObj.searchDatastoreSubFolders_Task(browserMor, dsPath, searchSpec)
      logger.info "MiqVimDataStore(#{@invObj.server}, #{@invObj.username}).dsSearch: returned from searchDatastoreSubFolders_Task"
    else
      logger.info "MiqVimDataStore(#{@invObj.server}, #{@invObj.username}).dsSearch: calling searchDatastore_Task"
      taskMor = @invObj.searchDatastore_Task(browserMor, dsPath, searchSpec)
      logger.info "MiqVimDataStore(#{@invObj.server}, #{@invObj.username}).dsSearch: returned from searchDatastore_Task"
    end

    retObj = waitForTask(taskMor)
    retObj = [retObj] unless retObj.kind_of?(Array)
    # @invObj.dumpObj(retObj)

    ra = VimArray.new
    retObj.each do |dsbr|
      dsl = (dsbr["folderPath"][-1, 1] == ']')

      dsbr["file"] = dsbr["file"] || []
      # dsbr["file"] = [dsbr["file"]] if !dsbr["file"].kind_of? Array

      dsbr["file"].each do |fInfo|
        path = nil
        if dsl
          path = dsbr["folderPath"] + " " + fInfo["path"]
        else
          path = File.join(dsbr["folderPath"], fInfo["path"])
        end
        fInfo["fullPath"] = path
        if pathOnly
          ra << path
        else
          ra << fInfo
        end
      end
    end
    (ra)
  end

  def dsFolderFileList(path = nil)
    dirs = dsFolderFileSearch(nil, path, true, false).inject({}) { |h, d| h[d] = nil; h }

    children = VimArray.new
    ret = dsFileSearch(nil, path, false, false)

    ret.each do |f|
      full_path = f['fullPath']
      if dirs.key?(full_path)
        f['fileType'] = 'FolderFileInfo'
        full_path =~ /\] (.+)$/
        children.concat(dsFolderFileList($1))
      end
    end

    ret.concat(children)
  end

  def dsHash_locked(refresh = false)
    raise "dsHash_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dsHash) if @dsHash && !refresh

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      searchSpec = VimHash.new("HostDatastoreBrowserSearchSpec") do |hdbs|
        hdbs.details = VimHash.new("FileQueryFlags") do |fqf|
          fqf.fileSize    = "true"
          fqf.fileType    = "true"
          fqf.modification  = "true"
          fqf.fileOwner   = "true"
        end
        hdbs.sortFoldersFirst = "true"
      end

      logger.info "MiqVimDataStore(#{@invObj.server}, #{@invObj.username}).dsHash_locked: calling searchDatastoreSubFolders_Task"
      taskMor = @invObj.searchDatastoreSubFolders_Task(browser_locked, "[#{@name}]", searchSpec)
      logger.info "MiqVimDataStore(#{@invObj.server}, #{@invObj.username}).dsHash_locked: returned from searchDatastoreSubFolders_Task"

      retObj = waitForTask(taskMor)
      retObj = [retObj] unless retObj.kind_of?(Array)

      @dsHash = {}

      retObj.each do |dsbr|
        # puts "dsbr.class: #{dsbr.class.to_s}"
        # @invObj.dumpObj(dsbr)
        # puts "****** dsbr end"
        # puts "Folder Path: #{dsbr.folderPath}"
        dsl = (dsbr["folderPath"][-1, 1] == ']')

        if dsl
          rInfo = {}
          rInfo['fileType'] = "FolderFileInfo"
          @dsHash[dsbr["folderPath"]] = rInfo
        else
          dsbr["folderPath"] = dsbr["folderPath"][0..-2] if dsbr["folderPath"][-1, 1] == "/"
        end

        raise "[BUG] Parent directory '#{dsbr["folderPath"]}' not defined" unless (parentDir = @dsHash[dsbr["folderPath"]])
        parentDir['dirEntries'] = [] unless parentDir['dirEntries']
        dirEntries = parentDir['dirEntries']

        dsbr["file"] = dsbr["file"] || []
        dsbr["file"] = [dsbr["file"]] unless dsbr["file"].kind_of? Array

        dsbr["file"].each do |fInfo|
          # puts "***** fInfo.class: #{fInfo.class.to_s}"
          fInfoHash = fInfo
          # fInfoHash = @invObj.unMarshalSoapMappingObject(fInfo)
          fInfoHash['fileType'] = fInfoHash.xsiType
          # puts "\tType: #{fInfoHash['xmlattr_type']}, Path: #{fInfoHash["path"]}"
          if dsl
            path = dsbr["folderPath"] + " " + fInfoHash["path"]
          else
            path = File.join(dsbr["folderPath"], fInfoHash["path"])
          end
          fInfoHash['dirEntries'] = [] if fInfoHash['fileType'] == "FolderFileInfo" && !fInfoHash['dirEntries']
          dirEntries << fInfoHash["path"]
          @dsHash[path] = fInfoHash
        end
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    @dsHash
  end

  #
  # Public accessor
  #
  def dsHash(refresh = false)
    @cacheLock.synchronize(:SH) do
      return(dupObj(dsHash_locked(refresh)))
    end
  end


  def dumpProps
    props = @invObj.getMoProp_local(@dsMor, "browser")["browser"]
    @invObj.dumpObj(props)
  end

  def waitForTask(tmor)
    @invObj.waitForTask(tmor, self.class.to_s)
  end

  def get_file_content(filepath)
    # Sample URL required to read file
    # agentURI = "https://192.168.254.247/folder/BH_9336_1/BH_9336_1.vmsd?dcPath=ha-datacenter&dsName=DCRaid2"
    # Note: dcPath is only required if going through vCenter.
    raise "get_file_content not supported through Virtual Center" if @invObj.isVirtualCenter?
    /(\d*)\.(\d*)/ =~ @invObj.about['version']
    raise "get_file_content not supported on [#{@invObj.about['fullName']}]" if $1.to_i < 3 || ($1.to_i == 3 && $2.to_i < 5)

    fileUrl = encode_datastore_url(filepath, @name)

    options = {
      :http_basic_authentication => [@invObj.username, @invObj.password],
      :ssl_verify_mode           => OpenSSL::SSL::VERIFY_NONE
    }

    if block_given?
      open(fileUrl, options) { |ret| yield(ret) }
    else
      data = nil
      open(fileUrl, options) { |ret| data = ret.read }
      return data
    end
  end

  def dupObj(obj)
    obj
  end

  private

  def encode_datastore_url(file_path, ds_name)
    uri_parts = {
      :scheme => "https",
      :host   => @invObj.server,
      :path   => "/folder/#{encode_path_url(file_path)}",
      :query  => "dsName=#{encode_path_url(ds_name)}"
    }

    URI::Generic.build(uri_parts).to_s
  end

  def encode_path_url(path)
    URI::DEFAULT_PARSER.escape(path, /[^#{URI::PATTERN::UNRESERVED}]/o)
  end
end # module MiqVimDataStore
