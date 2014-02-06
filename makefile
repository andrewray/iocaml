all: _build/iocaml.top

SRC = iocaml_main.ml iocaml.ml message.ml sockets.ml log.ml \
	  iocaml.mli message.mli sockets.mli log.mli \
	  Ipython_json_t.mli Ipython_json_t.ml Ipython_json_j.mli Ipython_json_j.ml 

Ipython_json_t.mli Ipython_json_t.ml Ipython_json_j.mli Ipython_json_j.ml: Ipython_json.atd
	atdgen -t Ipython_json.atd
	atdgen -j Ipython_json.atd

_build/iocaml.top: $(SRC)
	ocamlbuild -use-ocamlfind -no-links \
		-pkg threads,ZMQ,uuidm,yojson,atdgen,cryptokit,compiler-libs \
		-cflag -thread -lflag -thread iocaml.top

BINDIR=`opam config var bin`

install: all
	ocamlfind install iocaml META _build/iocaml.cmi _build/Ipython_json_t.cmi \
		_build/Ipython_json_j.cmi _build/message.cmi _build/log.cmi _build/sockets.cmi
	cp _build/iocaml.top $(BINDIR)/iocaml.top

uninstall:
	ocamlfind remove iocaml

clean:
	ocamlbuild -clean
	- rm -f Ipython_json_t.mli Ipython_json_t.ml  
	- rm -f Ipython_json_j.mli Ipython_json_j.ml  
	- rm -f *~


