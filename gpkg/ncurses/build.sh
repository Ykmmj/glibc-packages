TERMUX_PKG_HOMEPAGE=https://invisible-island.net/ncurses/ncurses.html
TERMUX_PKG_DESCRIPTION="System V Release 4.0 curses emulation library"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux-pacman"
# Keep ncurses aligned with the bionic termux-packages recipe. This references
# https://github.com/ThomasDickey/ncurses-snapshots/commit/${_SNAPSHOT_COMMIT}.
_SNAPSHOT_COMMIT=5f58399b2de47ed14bdfe3a0cb149293b27893d5
_PKG_VERSION=6.5
_DATE_VERSION=20250830
TERMUX_PKG_VERSION=6.6.20260307+really6.5.20250830
TERMUX_PKG_SRCURL=https://github.com/ThomasDickey/ncurses-snapshots/archive/${_SNAPSHOT_COMMIT}.tar.gz
TERMUX_PKG_SHA256=28cd102efe6a2610e830cc79cf270da6ff0427b2022900a9a36d2761522f9576
TERMUX_PKG_DEPENDS="glibc, gcc-libs-glibc"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--disable-root-access
--disable-root-environ
--disable-setuid-environ
--enable-widec
--enable-pc-files
--mandir=$TERMUX_PREFIX/share/man
--with-cxx-binding
--with-cxx-shared
--with-manpage-format=normal
--with-pkg-config-libdir=$TERMUX_PREFIX/lib/pkgconfig
--with-shared
--with-versioned-syms
--with-xterm-kbs=del
--without-ada
"

termux_step_pre_configure() {
	local main_version patch_version actual_version expected_version
	main_version="$(cut -f 2 VERSION)"
	patch_version="$(cut -f 3 VERSION)"
	actual_version="${main_version}.${patch_version}"
	expected_version="${TERMUX_PKG_VERSION#*really}"
	if [[ "${actual_version}" != "${expected_version}" ]]; then
		termux_error_exit "Version mismatch - expected ${expected_version}, was ${actual_version}. Check ${_SNAPSHOT_COMMIT}"
	fi
}

termux_step_post_make_install() {
	for lib in ncurses ncurses++ form panel menu; do
		printf "INPUT(-l%sw)\n" "${lib}" > $TERMUX_PREFIX/lib/lib${lib}.so
		ln -svf ${lib}w.pc $TERMUX_PREFIX/lib/pkgconfig/${lib}.pc
	done

	printf 'INPUT(-lncursesw)\n' > $TERMUX_PREFIX/lib/libcursesw.so
	ln -svf libncurses.so $TERMUX_PREFIX/lib/libcurses.so

	for lib in tic tinfo; do
		printf "INPUT(libncursesw.so.%s)\n" "${_PKG_VERSION:0:1}" > $TERMUX_PREFIX/lib/lib${lib}.so
		ln -svf libncursesw.so.${TERMUX_PKG_VERSION:0:1} $TERMUX_PREFIX/lib/lib${lib}.so.${_PKG_VERSION:0:1}
		ln -svf ncursesw.pc $TERMUX_PREFIX/lib/pkgconfig/${lib}.pc
	done

	mkdir $TERMUX_PREFIX/include/ncurses
	for i in $TERMUX_PREFIX/include/ncursesw/*; do
		mv ${i} $TERMUX_PREFIX/include
		ln -s ../${i##*/} $TERMUX_PREFIX/include/ncurses
		ln -s ../${i##*/} $TERMUX_PREFIX/include/ncursesw
	done
}
