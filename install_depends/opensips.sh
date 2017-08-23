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

if [ "${MM_TYPE}" = "opensips" ]
then
  MM_DIR="${BUILDDIR}/dist/opensips"
  git clone -b "${MM_BRANCH}" git://github.com/OpenSIPS/opensips.git
  if [ "${MM_REV}" != "${MM_BRANCH}" ]
  then
    git -C opensips checkout "${MM_REV}"
  fi
  git -C opensips rev-parse HEAD
  perl -pi -e 's|-O[3-9]|-O0 -g3|' "${MM_DIR}/Makefile.defs"
  if [ "${MM_BRANCH}" != "1.11" -a "${MM_VER}" != "21" -a \
   "${MM_VER}" != "22" -a "${MM_BRANCH}" != "2.3" -a "${MM_BRANCH}" != "master" ]
  then
    git -C opensips apply ${BUILDDIR}/install_depends/opensips/rtpproxy_ip6.patch
  fi
  #if [ "${MM_BRANCH}" = "1.11" ]
  #then
  #  git -C opensips apply ${BUILDDIR}/install_depends/tm_none_on_cancel.patch 
  #fi
  if [ "${MM_BRANCH}" != "1.11" ]
  then
    MM_PATCH_SET="mod.rtpproxy_retry.diff"
    if [ "${MM_BRANCH}" != "master" ]
    then
      MM_PATCH_SET="mod.rtpproxy_iodebug.diff ${MM_PATCH_SET}"
    fi
    for p in ${MM_PATCH_SET}
    do
      git -C opensips apply ${BUILDDIR}/install_depends/opensips/${p}
    done
  fi
  if [ "${MM_BRANCH}" = "2.3" ]
  then
    git -C opensips revert -n 1eb4ec0f78f43f6ff546de49bc72e513876fb86b
    MM_KILL_MODULES="event_routing"
  fi
fi
if [ "${MM_TYPE}" = "b2bua" ]
then
  git clone -b "${MM_BRANCH}" git://github.com/sippy/b2bua.git
else
  git clone git://github.com/sippy/b2bua.git
fi
git -C b2bua rev-parse HEAD
git clone -b "${RTPP_BRANCH}" --recursive git://github.com/sippy/rtpproxy.git
git -C rtpproxy rev-parse HEAD
#git -C rtpproxy submodule update --init --recursive
if [ "${MM_TYPE}" = "kamailio" ]
then
  git clone -b "${MM_BRANCH}" git://github.com/kamailio/kamailio.git kamailio
  git -C kamailio rev-parse HEAD
  perl -pi -e 's|-O[3-9]|-O0 -g3| ; s|^run_target = .[(]run_prefix[)]/.[(]run_dir[)]|run_target = /tmp/kamailio|' \
   ${BUILDDIR}/dist/kamailio/Makefile.defs
  if [ "${MM_BRANCH}" = "4.1" ]
  then
    patch -p1 -s -d kamailio < ${BUILDDIR}/install_depends/kamailio/rtpproxy_ip6.patch
  fi
fi

##bash
if [ "${MM_TYPE}" = "opensips" ]
then
  for m in ${MM_KILL_MODULES}
  do
    rm -rf "${MM_DIR}/modules/${m}"
  done
  ${MAKE_CMD} -C "${MM_DIR}" CC_NAME=gcc CC="${CC}" \
   all modules
fi
if [ "${MM_TYPE}" = "kamailio" ]
then
  ${MAKE_CMD} -C "${BUILDDIR}/dist/kamailio" CC_NAME=gcc CC="${CC}" LD="${CC}" \
   include_modules="sl tm rr maxfwd rtpproxy textops" skip_modules="erlang" all modules
fi
cd rtpproxy
./configure
${MAKE_CMD} all
( cat ${BASEDIR}/install_depends/b2bua_radius.py.fix; \
  grep -v '^from sippy.Rtp_proxy_client import Rtp_proxy_client' ${BASEDIR}/dist/b2bua/sippy/b2bua_radius.py ) | \
  sed "s|%%SIPPY_ROOT%%|${BASEDIR}/dist/b2bua|" > ${BASEDIR}/dist/b2bua/sippy/b2bua_test.py
chmod 755 ${BASEDIR}/dist/b2bua/sippy/b2bua_test.py
