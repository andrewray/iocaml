all: _build/iocaml.top

FILES = iocaml message sockets log completion Ipython_json_t Ipython_json_j 
ML = $(foreach file,$(FILES),$(file).ml)
MLI = $(foreach file,$(FILES),$(file).mli)
CMO = $(foreach file,$(FILES),_build/$(file).cmo)
CMI = $(foreach file,$(FILES),_build/$(file).cmi)
CMT = $(foreach file,$(FILES),_build/$(file).cmt)
CMTI = $(foreach file,$(FILES),_build/$(file).cmti)

SRC = iocaml_main.ml $(ML) $(MLI)

PKG = threads,ZMQ,uuidm,yojson,atdgen,cryptokit,netstring,compiler-libs,ocp-index.lib,optcomp 

Ipython_json_t.mli Ipython_json_t.ml Ipython_json_j.mli Ipython_json_j.ml: Ipython_json.atd
	atdgen -t Ipython_json.atd
	atdgen -j Ipython_json.atd

_build/iocaml.top: $(SRC)
	echo $(ML)
	ocamlbuild -use-ocamlfind -no-links \
		-pkg $(PKG) \
		-cflag -thread -lflag -thread iocaml.top

BINDIR=`opam config var bin`

install: all
	ocamlfind install iocaml META $(CMI) $(CMO) $(CMT) $(CMTI)
	cp _build/iocaml.top $(BINDIR)/iocaml.top

uninstall:
	ocamlfind remove iocaml

clean:
	ocamlbuild -clean
	- rm -f Ipython_json_t.mli Ipython_json_t.ml  
	- rm -f Ipython_json_j.mli Ipython_json_j.ml  
	- rm -f *~


