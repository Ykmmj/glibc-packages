#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${repo_root}"

read_json() {
	local expr="$1"

	python3 - "${expr}" repo.json <<'PY'
import json
import sys

expr = sys.argv[1]
path = sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

current = data
for part in expr.split("."):
    if not part:
        continue
    current = current[part]
print(current)
PY
}

require_equal() {
	local actual="$1"
	local expected="$2"
	local label="$3"

	if [[ "${actual}" != "${expected}" ]]; then
		echo "${label}: expected '${expected}', got '${actual}'" >&2
		exit 1
	fi
}

require_equal "$(read_json '.pkg_format')" "debian" "pkg_format"
require_equal "$(read_json '.gpkg.url')" "https://ykmmj.github.io/termuxd-packages-repo/apt/glibc" "gpkg.url"
require_equal "$(read_json '.gpkg.distribution')" "stable" "gpkg.distribution"
require_equal "$(read_json '.gpkg.component')" "main" "gpkg.component"

runner_depends="$(grep '^TERMUX_PKG_DEPENDS=' gpkg/glibc-runner/build.sh)"
[[ "${runner_depends}" == *"bash"* ]] || {
	echo "glibc-runner must keep the bionic bash bridge dependency" >&2
	exit 1
}

grep -q '@TERMUX_PREFIX_CLASSICAL@' gpkg/glibc-runner/glibc-runner.sh

grep -q '^export SHELL="${GLIBC_PREFIX}/bin/bash"$' gpkg/glibc-runner/glibc-runner.bashrc || {
	echo "glibc-runner must override inherited Android SHELL values so -s enters glibc bash" >&2
	exit 1
}

grep -q 'export CGCT_DIR="/data/data/com.termux/cgct"' cgct/glibc-cgct/setup-cgct || {
	echo "glibc-cgct setup must keep the upstream CGCT path" >&2
	exit 1
}

grep -q 'HOSTCC=/usr/bin/gcc' gpkg/linux-api-headers/build.sh || {
	echo "linux-api-headers must build kernel host tools with the system host gcc" >&2
	exit 1
}

grep -q 'TERMUX_PKG_VERSION=6.6.20260307+really6.5.20250830' gpkg/ncurses/build.sh || {
	echo "ncurses-glibc must stay aligned with the bionic ncurses version" >&2
	exit 1
}

grep -q -- '-DCMAKE_POLICY_VERSION_MINIMUM=3.5' gpkg/json-c/build.sh || {
	echo "json-c-glibc must keep the CMake 4 compatibility policy minimum" >&2
	exit 1
}

grep -q 'TERMUX_PKG_DEPENDS="attr"$' gpkg/libacl/build.sh || {
	echo "libacl-glibc must depend on bare attr so the glibc build graph can order attr-glibc first" >&2
	exit 1
}

if grep -q '^TERMUX_PKG_BUILD_DEPENDS=.*gettext' gpkg/attr/build.sh; then
	echo "attr-glibc must not build-depend on gettext-glibc because gettext pulls libacl-glibc" >&2
	exit 1
fi
grep -q -- '--enable-gettext=no' gpkg/attr/build.sh || {
	echo "attr-glibc must disable gettext like the bionic attr recipe" >&2
	exit 1
}

grep -q 'github.com/madler/zlib/releases/download/v${TERMUX_PKG_VERSION}' gpkg/zlib/build.sh || {
	echo "zlib-glibc must use the stable upstream release URL instead of the rolling zlib.net current URL" >&2
	exit 1
}

if grep -q 'e2fsprogs-glibc' gpkg/krb5/build.sh || grep -q -- '--with-system-et\|--with-system-ss' gpkg/krb5/build.sh; then
	echo "krb5-glibc must use bundled et/ss to avoid the krb5/e2fsprogs/util-linux dependency cycle" >&2
	exit 1
fi
grep -q -- '-std=gnu17' gpkg/krb5/build.sh || {
	echo "krb5-glibc must pin gnu17 so bundled ss builds with pre-C23 empty-prototype semantics" >&2
	exit 1
}
grep -q 'TERMUX_PKG_GIT_BRANCH=main' gpkg/publicsuffix-list/build.sh || {
	echo "publicsuffix-list-glibc must clone the current upstream main branch before checking out its pinned commit" >&2
	exit 1
}
grep -q -- '-std=gnu17' gpkg/libgmp/build.sh || {
	echo "libgmp-glibc must pin gnu17 so GMP configure works with pre-C23 empty-prototype semantics" >&2
	exit 1
}
grep -q -- '-std=gnu17' gpkg/p11-kit/build.sh || {
	echo "p11-kit-glibc must pin gnu17 so its legacy bool compatibility typedef builds before C23" >&2
	exit 1
}

grep -q -- '-std=gnu17' gpkg/libdb/build.sh || {
	echo "libdb-glibc must pin gnu17 so Berkeley DB legacy empty-prototype function pointers build before C23" >&2
	exit 1
}

if grep -q -- '--enable-stl' gpkg/libdb/build.sh; then
	echo "libdb-glibc must not enable Berkeley DB STL bindings; they require unconfigured TLS support in this cross build" >&2
	exit 1
fi

if grep '^TERMUX_PKG_DEPENDS=' gpkg/glibc-runner/build.sh | grep -q 'strace-glibc'; then
	echo "glibc-runner must keep strace-glibc optional so the standalone shell MVP does not force perl-glibc" >&2
	exit 1
fi

grep -q '^TERMUX_PKG_SUGGESTS="strace-glibc"$' gpkg/glibc-runner/build.sh || {
	echo "glibc-runner should suggest strace-glibc for optional debug mode" >&2
	exit 1
}

grep -q '^TERMUX_PKG_SHA256=175d7c9eac6f9fc3b949d1a2cee5f5d3ace61420d418d8213369eb6aff18d28f$' gpkg/termux-exec/build.sh || {
	echo "termux-exec-glibc checksum must match the current v1.0 GitHub archive" >&2
	exit 1
}

grep -q '^TERMUX_PKG_SKIP_SRC_EXTRACT=true$' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must package upstream CGCT runtime libs without rebuilding GCC" >&2
	exit 1
}

grep -q 'CGCT_DIR:-/data/data/com.termux/cgct' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must reuse the upstream CGCT runtime library directory" >&2
	exit 1
}

grep -q '/usr/bin/patchelf' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must call host /usr/bin/patchelf instead of any target patchelf in PATH" >&2
	exit 1
}

grep -q '"${host_patchelf}" --set-rpath "${TERMUX_PREFIX}/lib"' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must rewrite upstream CGCT runtime RPATH to the termuxd glibc prefix" >&2
	exit 1
}

grep -q 'chmod u+w "${output_lib}"' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must make copied CGCT runtime libraries writable before patchelf" >&2
	exit 1
}

grep -q 'copied_libs' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must only rewrite the CGCT runtime libraries copied by this package" >&2
	exit 1
}

if grep -q 'find "${TERMUX_PREFIX}/lib"' gpkg/gcc-libs/build.sh; then
	echo "gcc-libs-glibc must not scan the whole glibc lib directory; it would absorb dependency package files" >&2
	exit 1
fi

grep -q '\*-gdb.py' gpkg/gcc-libs/build.sh || {
	echo "gcc-libs-glibc must not package libstdc++ gdb helper scripts from CGCT runtime globs" >&2
	exit 1
}

[[ -f gpkg/gcc-libs/gcc.subpackage.sh ]] || {
	echo "gcc-glibc metadata placeholder is required so buildorder accepts legacy clang-glibc deps" >&2
	exit 1
}

grep -q '^TERMUX_SUBPKG_PLATFORM_INDEPENDENT=true$' gpkg/gcc-libs/gcc.subpackage.sh || {
	echo "gcc-glibc placeholder must stay platform independent so an empty package is not emitted" >&2
	exit 1
}

grep -q '^TERMUX_SUBPKG_INCLUDE=""$' gpkg/gcc-libs/gcc.subpackage.sh || {
	echo "gcc-glibc placeholder must not include compiler files" >&2
	exit 1
}

if find gpkg/gcc-libs -maxdepth 1 -name '*.patch' -print -quit | grep -q .; then
	echo "gcc-libs-glibc uses no source tree, so old GCC patch files must not remain" >&2
	exit 1
fi

if [[ -e gpkg/resolv-conf/build.sh ]]; then
	echo "resolv-conf must remain the bionic/classical resolver package, not a glibc package" >&2
	exit 1
fi

grep -q 'ln -sf \$TERMUX_PREFIX_CLASSICAL/etc/resolv.conf \$TERMUX_PREFIX/etc' gpkg/openssl/build.sh || {
	echo "openssl-glibc must create resolver config symlinks idempotently" >&2
	exit 1
}

echo "termuxd glibc config ok"
