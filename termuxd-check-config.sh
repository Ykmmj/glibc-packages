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

echo "termuxd glibc config ok"
