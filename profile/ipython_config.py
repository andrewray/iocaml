# Configuration file for iocaml.
# set up the path to iocaml.top in kernel_cmd.
c = get_config()
c.KernelManager.kernel_cmd = [ 'iocaml.top', 
                                    #'-log', 'iocaml.log', 
                                    '-completion',
                                    '-object-info',
                                    '-thread',
                                    '-syntax', 'camlp4o',
                                    '-package', 'iocaml',
                                    '-connection-file', '{connection_file}' 
                             ]
c.Session.key = b''
c.Session.keyfile = b''

