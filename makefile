all: _build/iocaml.top

FILES = log Ipython_json_t Ipython_json_j base64 message sockets completion exec iocaml
ML = $(foreach file,$(FILES),$(file).ml)
MLI = $(foreach file,$(FILES),$(file).mli)
CMO = $(foreach file,$(FILES),_build/$(file).cmo)
CMO_TGT = $(foreach file,$(FILES),$(file).cmo)
CMI = $(foreach file,$(FILES),_build/$(file).cmi)
CMT = $(foreach file,$(FILES),_build/$(file).cmt)
CMTI = $(foreach file,$(FILES),_build/$(file).cmti)

SRC = iocaml_main.ml $(ML) $(MLI)

Ipython_json_t.mli Ipython_json_t.ml Ipython_json_j.mli Ipython_json_j.ml: Ipython_json.atd
	atdgen -t Ipython_json.atd
	atdgen -j Ipython_json.atd

# manually link ocp-index.  proper ocamlfind package includes
# compiler-libs which breaks toplevels built with ocamlmktop.
OCP_INDEX_INC=`ocamlfind query ocp-index.lib -predicates byte -format "%d"`
OCP_INDEX_ARCHIVE=`ocamlfind query ocp-index.lib -predicates byte -format "%a"`

_build/iocaml.top: $(SRC)
	ocamlbuild -use-ocamlfind $(CMO_TGT) iocaml_main.cmo
	ocamlfind ocamlmktop -g -thread -linkpkg \
		-package threads,ZMQ,uuidm,yojson,atdgen,ocp-indent.lib,compiler-libs \
		-I $(OCP_INDEX_INC) \
		$(OCP_INDEX_INC)/$(OCP_INDEX_ARCHIVE) \
		$(CMO) _build/iocaml_main.cmo \
		-o _build/iocaml.top

BINDIR=`opam config var bin`

install: all
	ocamlfind install iocaml META $(CMI) $(CMO) $(CMT) $(CMTI)
	cp _build/iocaml.top $(BINDIR)/iocaml.top

uninstall:
	ocamlfind remove iocaml
	rm -f $(BINDIR)/iocaml.top

reinstall:
	-$(MAKE) uninstall
	$(MAKE) install

clean:
	ocamlbuild -clean
	- rm -f Ipython_json_t.mli Ipython_json_t.ml  
	- rm -f Ipython_json_j.mli Ipython_json_j.ml  
	- rm -f *~

######################################################################
# we have build problems.  lets see if we can sort them out


