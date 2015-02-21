#!/bin/sh

set -e

BASEDIR="${BASEDIR:-$(dirname -- "${0}")/..}"
BASEDIR="$(readlink -f -- ${BASEDIR})"

. ${BASEDIR}/functions

if [ -e "${BUILDDIR}/dist" ]
then
  rm -rf "${BUILDDIR}/dist"
fi
mkdir "${BUILDDIR}/dist"
cd "${BUILDDIR}/dist"

git clone -b 1.10 git://github.com/OpenSIPS/opensips.git
git clone git://github.com/sippy/b2bua.git
git clone git://github.com/sippy/rtpproxy.git

perl -pi -e 's|-O[3-9]|-O0 -g3|' ${BUILDDIR}/dist/opensips/Makefile.defs
##bash
${MAKE_CMD} -C "${BUILDDIR}/dist/opensips" CC_NAME=gcc CC="${CC}" all modules
cd rtpproxy
./configure
${MAKE_CMD} all
cat ${BASEDIR}/install_depends/b2bua_radius.py.fix ${BASEDIR}/dist/b2bua/sippy/b2bua_radius.py | \
  sed "s|%%SIPPY_ROOT%%|${BASEDIR}/dist/b2bua|" > ${BASEDIR}/dist/b2bua/sippy/b2bua_test.py
chmod 755 ${BASEDIR}/dist/b2bua/sippy/b2bua_test.py