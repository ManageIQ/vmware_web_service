require 'rbvmomi'
require 'rbvmomi/pbm'

PbmVimConnection = Struct.new(:host, :cookie)

class PbmService
  def initialize(vim, insecure: true)
    @pbm = RbVmomi::PBM.connect(vim, :insecure => insecure)
    @sic = @pbm.serviceContent
  end

  def queryAssociatedEntity(profileId)
    @sic.profileManager.PbmQueryAssociatedEntity(:profile => profileId)
  end

  def queryMatchingHub(profileId, hubsToSearch = nil)
    @sic.placementSolver.PbmQueryMatchingHub(
      :profile      => profileId,
      :hubsToSearch => hubsToSearch
    )
  end

  def queryProfile
    @sic.profileManager.PbmQueryProfile(
      :resourceType => RbVmomi::PBM::PbmProfileResourceType(:resourceType => "STORAGE")
    )
  end

  def retrieveContent(profileIds)
    @sic.profileManager.PbmRetrieveContent(:profileIds => profileIds)
  end
end
