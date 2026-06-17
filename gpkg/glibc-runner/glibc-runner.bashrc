# @TERMUX_PREFIX_CLASSICAL@/etc/glibc-runner.bashrc
# this script is for setting up the glibc-runner shell environment

if [ -f "${GLIBC_PREFIX}/etc/locale.conf" ]; then
	source "${GLIBC_PREFIX}/etc/locale.conf"
fi

export SHELL="${GLIBC_PREFIX}/bin/bash"
