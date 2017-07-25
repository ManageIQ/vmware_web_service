# When these classes are deserialized in ActiveRecord (e.g. EmsEvent, MiqQueue), they need to be preloaded
autoload :VimType,   'VMwareWebService/VimTypes'
autoload :VimHash,   'VMwareWebService/VimTypes'
autoload :VimArray,  'VMwareWebService/VimTypes'
autoload :VimString, 'VMwareWebService/VimTypes'
autoload :VimFault,  'VMwareWebService/VimTypes'
autoload :VimClass,  'VMwareWebService/VimTypes'
