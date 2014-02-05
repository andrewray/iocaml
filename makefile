all: _build/iocaml.top

Ipython_json_t.mli Ipython_json_t.ml Ipython_json_j.mli Ipython_json_j.ml: Ipython_json.atd
	atdgen -t Ipython_json.atd
	atdgen -j Ipython_json.atd

_build/iocaml.top: iocaml.ml Ipython_json_t.mli Ipython_json_t.ml Ipython_json_j.mli Ipython_json_j.ml 
	ocamlbuild -use-ocamlfind -no-links \
		-pkg threads,ZMQ,uuidm,yojson,atdgen,cryptokit,compiler-libs.toplevel \
		-cflag -thread -lflag -thread iocaml.top

clean:
	ocamlbuild -clean
	- rm -f Ipython_json_t.mli Ipython_json_t.ml  
	- rm -f Ipython_json_j.mli Ipython_json_j.ml  
	- rm -f *~


