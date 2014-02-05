# Configuration file for iocaml.
# set up the path to iocaml.top in kernel_cmd.
c = get_config()
c.KernelManager.kernel_cmd = [ '/your/path/iocaml.top', '{connection_file}' ]
c.Session.key = b''
c.Session.keyfile = b''

