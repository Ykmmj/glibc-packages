TERMUX_PKG_HOMEPAGE=https://gcc.gnu.org/
TERMUX_PKG_DESCRIPTION="Runtime libraries shipped by the upstream CGCT GCC"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux-pacman"
TERMUX_PKG_VERSION=15.2.0
TERMUX_PKG_DEPENDS="glibc"
TERMUX_PKG_BREAKS="gcc-glibc-libs-dev"
TERMUX_PKG_REPLACES="gcc-glibc-libs-dev"
TERMUX_PKG_NO_STATICSPLIT=true
TERMUX_PKG_SKIP_SRC_EXTRACT=true

termux_step_make_install() {
	local cgct_lib_dir="${CGCT_DIR:-/data/data/com.termux/cgct}/${TERMUX_ARCH}/lib"
	if [[ ! -d "${cgct_lib_dir}" ]]; then
		termux_error_exit "CGCT runtime library directory not found: ${cgct_lib_dir}"
	fi
	if ! command -v patchelf >/dev/null; then
		termux_error_exit "patchelf is required to rewrite CGCT runtime library RPATH"
	fi

	mkdir -p "${TERMUX_PREFIX}/lib"

	local pattern runtime_lib
	for pattern in \
		libgcc_s.so* \
		libstdc++.so* \
		libatomic.so* \
		libgomp.so* \
		libitm.so* \
		libasan.so* \
		liblsan.so* \
		libtsan.so* \
		libubsan.so*; do
		for runtime_lib in "${cgct_lib_dir}"/${pattern}; do
			[[ "$(basename "${runtime_lib}")" == *-gdb.py ]] && continue
			if [[ -e "${runtime_lib}" || -L "${runtime_lib}" ]]; then
				cp -a "${runtime_lib}" "${TERMUX_PREFIX}/lib/"
			fi
		done
	done

	local output_lib
	while IFS= read -r -d '' output_lib; do
		if file "${output_lib}" | grep -q 'ELF .* shared object'; then
			patchelf --set-rpath "${TERMUX_PREFIX}/lib" "${output_lib}"
		fi
	done < <(find "${TERMUX_PREFIX}/lib" -maxdepth 1 -type f -name 'lib*.so*' -print0)
}
