IOCaml
======

IOCaml is an OCaml kernel for the 
[IPython notebook](http://ipython.org/notebook.html). 
This provides a REPL within a web browser with a nice user interface 
including markdown based comments/documentation, mathjax formula and 
the possibility of generating all manner of HTML based output media 
from your code.  

See also

* [IOCaml-kernel](https://github.com/andrewray/iocaml)
* [IOCamlJS-kernel](https://github.com/andrewray/iocamljs)
* [IOCaml-server](https://github.com/andrewray/iocamlserver)

This repository hosts the iocaml-kernel package.

![Example picture](https://github.com/andrewray/iocaml/raw/master/notebooks/notebook-example-polys.png)

# Installation

Installation requires opam and OCaml >= 4.01.0.

The kernels can be used with either the IOCaml notebook server or 
the IPython server.  Installation of the later is described 
[here](https://github.com/andrewray/iocaml/wiki/ipython_install).

To use the OCaml server you just need to 

```
$ opam install iocaml
```

which will also install the kernels.  To just install the kernels use

```
$ opam install iocaml-kernel
$ opam install iocaml-kerneljs
```

## Command line options

The following options may be given to the IOCaml-kernel (via
the IPython profile config) or IOCaml-server.

* ``` -log <filename> ``` open log file
* ``` -init <file> ``` load ```file``` instead of default init file
* ``` -completion ``` enable tab completion
* ``` -object-info ``` enable introspection

The following option is for use with IPython

* ``` -connection-file <filename> ``` connection file name

