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

top: lib
	ocamlfind c -c -g -thread \
		-package threads,uuidm,yojson,atdgen,ocp-index.lib,compiler-libs \
		message.mli sockets.mli completion.mli exec.mli iocaml.mli \
		message.ml  sockets.ml  completion.ml  exec.ml  iocaml.ml 
	ocamlfind ocamlmktop -g -thread -linkpkg \
		-o iocaml.top \
		-package threads,uuidm,lwt.unix,ctypes.foreign,yojson,atdgen,ocp-indent.lib,compiler-libs \
		-I $(OCP_INDEX_INC) \
		$(OCP_INDEX_INC)/$(OCP_INDEX_ARCHIVE) \
		iocaml_lib.cma message.cmo sockets.cmo completion.cmo exec.cmo iocaml.cmo iocaml_main.ml

BINDIR=`opam config var bin`

install: top
	ocamlfind install iocaml META *.cmi *.cmo *.cma *.so *.a *.o
	cp iocaml.top $(BINDIR)/iocaml.top

uninstall:
	ocamlfind remove iocaml
	rm -f $(BINDIR)/iocaml.top

reinstall:
	-$(MAKE) uninstall
	$(MAKE) install

clean:
	rm *.cmi *.cmo *.cma *.so *.a *.o iocaml.top


