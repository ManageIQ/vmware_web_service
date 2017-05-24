module MiqException
  class Error < RuntimeError; end

  class MiqVimError < Error; end
  class MiqVimBrokerStaleHandle < MiqVimError; end
  class MiqVimBrokerUnavailable < MiqVimError; end
  # MiqVimResourceNotFound is derived from RuntimeError to ensure it gets marshalled over DRB properly.
  # TODO: Rename MiqException::Error class to avoid issues returning derived error classes over DRB.
  #       Then change MiqVimResourceNotFound to derive from MiqVimError
  class MiqVimResourceNotFound < RuntimeError; end

  # MiqVimVm Errors
  class MiqVimVmSnapshotError < MiqVimError; end
end
