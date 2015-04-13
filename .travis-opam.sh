### User-defined variables

# The package name
pkg=${PACKAGE:-my-package}

# Run the basic installation step
install_run=${INSTALL:-true}

# Run the optional dependency step
depopts_run=${DEPOPTS:-false}

# Run the test step
tests_run=${TESTS:-true}

# Run the reverse dependency rebuild step
revdep_run=${REVDEPS:-false}

# If a fork of these scripts are specified, use that GitHub user instead
fork_user=${FORK_USER:-ocaml}

# other variables
EXTRA_DEPS=${EXTRA_DEPS:-""}
PRE_INSTALL_HOOK=${PRE_INSTALL_HOOK:-""}
POST_INSTALL_HOOK=${POST_INSTALL_HOOK:-""}

### Script

set -ue
unset TESTS

install() {
  if [ "$EXTRA_DEPS" != "" ]; then
    opam depext $EXTRA_DEPS
    opam install $EXTRA_DEPS
  fi

  eval ${PRE_INSTALL_HOOK}
  echo "opam install ${pkg} $@"
  opam install ${pkg} $@
  eval ${POST_INSTALL_HOOK}

  if [ "$EXTRA_DEPS" != "" ]; then
    opam remove $EXTRA_DEPS
  fi
}

wget https://raw.githubusercontent.com/${fork_user}/ocaml-travisci-skeleton/master/.travis-ocaml.sh
sh .travis-ocaml.sh
export OPAMYES=1
eval $(opam config env)

opam pin add ${pkg} . -n
eval $(opam config env)

# Install the external dependencies
echo "opam depext ${pkg}"
opam depext ${pkg}

# Install the OCaml dependencies
echo "opam install ${pkg} --deps-only"
opam install ${pkg} --deps-only

# Simple installation/removal test
if [ "${install_run}" == "true" ]; then
    install -v
    echo "opam remove ${pkg} -v"
    opam remove ${pkg} -v
else
    echo "INSTALL=false, skipping the basic installation run."
fi

# Compile and run the tests as well
if [ "${tests_run}" == "true" ]; then
    echo "opam install ${pkg} --deps-only -t"
    opam install ${pkg} --deps-only -t
    install -v -t
    echo "opam remove ${pkg} -v"
    opam remove ${pkg} -v
else
    echo "TESTS=false, skipping the test run."
fi

# Compile with optional dependencies
if [ "${depopts_run}" != "false" ]; then
    # pick from $DEPOPTS if set or query OPAM
    depopts=${DEPOPTS:-$(opam show ${pkg} | grep -oP 'depopts: \K(.*)' | sed 's/ | / /g')}
    echo "opam depext ${depopts}"
    opam depext ${depopts}
    echo "opam install ${depopts}"
    opam install ${depopts}
    install -v
    echo "opam remove ${pkg} -v"
    opam remove ${pkg} -v
    echo "opam remove ${depopts}"
    opam remove ${depopts}
else
    echo "DEPOPTS=false, skipping the optional dependency run."
fi

if [ "${revdep_run}" != "false" ]; then
    packages=$(opam list --depends-on ${pkg} --short)
    for dependency in $packages; do
        echo "opam depext ${dependency}"
        opam depext ${dependency}
        echo "opam install ${dependency}"
        opam install ${dependency}
        echo "opam remove ${dependency}"
        opam remove ${dependency}
    done
else
    echo "REVDEPS=false, skipping the reverse dependency rebuild run."
fi
