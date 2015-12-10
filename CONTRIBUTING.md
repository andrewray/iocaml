### Manual Testing
This section describes how to test manually latest build during project development.
When all steps are done to test changes in the code required to make only two things:

- Recompile `make`.
- Restart kernel in the running Jupyter notebook.

#### Initial configuration

- Install Jupyter. This step involves some dealing with python infrastructure. 
  
  Use `pip install --user --upgrade jupiter` command to install Jupyter for the current user, not system-wide. 
  
  It is recommend to create a python virtual environment and install Jupiter there for better isolation. Your choice depends on the confidence in Python ecosystem.
  
- Test that Jupyter is installed correctly. Run server `jupyter notebook`
  
- Now we need to install `iocaml` as a kernel for Jupyter. 
  
  - Go to the `iocaml` project directory.
    
  - Create a `kernel.son` file with the following content
    
    ``` 
    {
     "display_name": "OCaml",
     "language": "ocaml",
     "argv": [
         "</path/to/the/iocaml-src-dir>/iocaml/iocaml.top",
          "-log",
          "iocaml.log",
          "-object-info",
          "-completion",
          "-connection-file",
          "{connection_file}"
     ]
    }
    ```
    
  - Let Jupyter know that we have OCaml Kernel
    
    ``` 
    jupyter kernelspec install --name iocaml-kernel `pwd`
    ```
    
    **Important** we use `pwd` command so we should be in the `iocaml` source directory!
    
  - `opam install cop-index` to get support of the `-completion`
    
  - Ensure that you have a `ZeroMq 3.x` installed.
    
    - For OS X
      
      ``` 
      brew tap caskroom/versions
      brew install homebrew/versions/zeromq3
      ```
      
    - For Ubuntu (recommend to use [preconfigured docker environment](https://github.com/signalpillar/ocaml-playground))
      
      ``` 
      # 0) `vivid` doesn't have add-apt-repository by default, we have to install it
      # 1) apt-get install -y --no-install-recommends software-properties-common
      # 2)
      add-apt-repository -y ppa:chris-lea/zeromq
      # 3) libzmq3-dev
      ```
    
  - Build `iocaml` project - `make`
    
  - Run Jupyter (OS X specific in part of `DYLD_LIBRARY_PATH` so it knows where to look for `dlliocaml_lib.so`)
    
    ``` 
    DYLD_LIBRARY_PATH=`pwd`:$DYLD_LIBRARY_PATH \
    && eval `opam config env` \
    && jupyter notebook \
    	--debug \
        --Session.keyfile=./keyfile \
        --notebook-dir=notebooks \
        --no-browser
    ```
