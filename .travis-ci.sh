OPAM_DEPENDS="sexplib ipaddr cstruct stringext uri vchan"

case "$OCAML_VERSION,$OPAM_VERSION" in
4.00.1,1.1.0) ppa=avsm/ocaml40+opam11 ;;
4.00.1,1.2.0) ppa=avsm/ocaml40+opam12 ;;
4.01.0,1.1.0) ppa=avsm/ocaml41+opam11 ;;
4.01.0,1.2.0) ppa=avsm/ocaml41+opam12 ;;
4.02.1,1.1.0) ppa=avsm/ocaml42+opam11 ;;
4.02.1,1.2.0) ppa=avsm/ocaml42+opam12 ;;
*) echo Unknown $OCAML_VERSION,$OPAM_VERSION; exit 1 ;;
esac

echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam time libssl-dev
sudo apt-get install libxen-dev uuid-dev

export OPAMYES=1
echo OCaml version
ocaml -version
echo OPAM versions
opam --version
opam --git-version

opam init -a
opam remote add mirage-dev git://github.com/mirage/mirage-dev
opam update
opam install ${OPAM_DEPENDS}

eval `opam config env`
make

opam install lwt
make clean
make
make install

opam remove lwt
opam install async
make clean
make
make install

opam install async_ssl
make clean
make
make install

opam install lwt
make clean
make
make install

opam install ssl
make clean
make
make install

opam install dns tcpip mirage-types vchan
make clean
make
make install

opam install cohttp cowabloga
