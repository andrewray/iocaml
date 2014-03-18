# Configuration file for iocaml.
# set up the path to iocaml.top in kernel_cmd.
c = get_config()
c.KernelManager.kernel_cmd = [ 'iocaml.top', 
                                    '-completion',
                                    '-object-info',
                                    '-connection-file', '{connection_file}' 
                             ]
c.Session.key = b''
c.Session.keyfile = b''

