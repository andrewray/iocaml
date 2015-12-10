# install OCaml + OPAM
case "$OCAML_VERSION,$OPAM_VERSION" in
3.12.1,1.0.0) ppa=avsm/ocaml312+opam10 ;;
3.12.1,1.1.0) ppa=avsm/ocaml312+opam11 ;;
4.00.1,1.0.0) ppa=avsm/ocaml40+opam10 ;;
4.00.1,1.1.0) ppa=avsm/ocaml40+opam11 ;;
4.01.0,1.0.0) ppa=avsm/ocaml41+opam10 ;;
4.01.0,1.1.0) ppa=avsm/ocaml41+opam11 ;;
4.02.3,1.2.2) ppa=avsm/ocaml42+opam12;;
*) echo Unknown $OCAML_VERSION,$OPAM_VERSION; exit 1 ;;
esac

PKG=iocaml-kernel.999.9.9

# install ocaml compilers
echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam libffi-dev

# initialize opam
export OPAMYES=1
opam init
eval `opam config env`

opam remote add iocaml-dev git://github.com/andrewray/opam.git
opam update

# install external deps
DEPEXT=`opam install $PKG -e ubuntu`
if [ "$DEPEXT" != "" ]; then
sudo apt-get install -qq $DEPEXT
fi

# install package deps
opam install ctypes-foreign
opam install $PKG --deps-only

# build 
make

