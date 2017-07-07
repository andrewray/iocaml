# new makefile - the build is about to get more complex.

all: top

json:
	atdgen -t Ipython_json.atd
	atdgen -j Ipython_json.atd

stub:
	ocamlfind c iocaml_zmq_stubs.c

lib: json stub
	# compile log (first so we can use it in the zmq code)
	ocamlfind c -c -g log.mli log.ml
	# iocaml_zmq (which requires preprocessing)
	ocamlfind c -c -g \
		-syntax camlp4o -package lwt.unix,lwt.syntax,ctypes.foreign \
		iocaml_zmq.mli iocaml_zmq.ml  
	# rest of the library
	ocamlfind c -c -g \
		-package yojson,atdgen,compiler-libs \
		Ipython_json_t.mli Ipython_json_j.mli base64.mli \
		Ipython_json_t.ml  Ipython_json_j.ml  base64.ml  
	ocamlfind ocamlmklib -o iocaml_lib \
		-l zmq \
		-package ctypes.foreign,lwt.unix,yojson \
		iocaml_zmq_stubs.o \
		log.cmo Ipython_json_t.cmo Ipython_json_j.cmo iocaml_zmq.cmo base64.cmo 

OCP_INDEX_INC=`ocamlfind query ocp-index.lib -predicates byte -format "%d"`
OCP_INDEX_ARCHIVE=`ocamlfind query ocp-index.lib -predicates byte -format "%a"`

HAS_OCP = $(shell if ocamlfind query ocp-index.lib >/dev/null 2>&1; then echo 1; else echo 0; fi)
ifeq ($(HAS_OCP),1)
TOP_PKG=threads,uuidm,lwt.unix,ctypes.foreign,yojson,atdgen,ocp-indent.lib,compiler-libs
TOP_SRC = \
	message.mli sockets.mli iocaml_comm.mli completion.mli exec.mli iocaml.mli \
	message.ml  sockets.ml  iocaml_comm.ml  completion.ml  exec.ml  iocaml.ml
TOP_OBJ =  message.cmo sockets.cmo iocaml_comm.cmo completion.cmo exec.cmo iocaml.cmo
TOP_OCP = -I $(OCP_INDEX_INC) $(OCP_INDEX_INC)/$(OCP_INDEX_ARCHIVE)
else
TOP_PKG=threads,uuidm,lwt.unix,ctypes.foreign,yojson,atdgen,compiler-libs
TOP_SRC = \
	message.mli sockets.mli iocaml_comm.mli exec.mli iocaml.mli \
	message.ml  sockets.ml  iocaml_comm.ml  exec.ml  iocaml.ml
TOP_OBJ =  message.cmo sockets.cmo iocaml_comm.cmo exec.cmo iocaml.cmo
TOP_OCP =
endif

top: lib
	ocamlfind c -c -g -thread \
		-syntax camlp4o -package optcomp -ppopt "-let has_ocp=$(HAS_OCP)" \
		-package $(TOP_PKG) \
		$(TOP_OCP) $(TOP_SRC)
	ocamlfind ocamlmktop -g -thread -linkpkg \
		-o iocaml.top \
		-package $(TOP_PKG) $(TOP_OCP) \
		iocaml_lib.cma $(TOP_OBJ) iocaml_main.ml

BINDIR=`opam config var bin`

install: top
	ocamlfind install iocaml-kernel META *.cmi *.cmo *.cma *.so *.a *.o
	cp iocaml.top $(BINDIR)/iocaml.top

uninstall:
	ocamlfind remove iocaml-kernel
	rm -f $(BINDIR)/iocaml.top

reinstall:
	-$(MAKE) uninstall
	$(MAKE) install

clean:
	rm *.cmi *.cmo *.cma *.so *.a *.o iocaml.top


