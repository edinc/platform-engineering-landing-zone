#!/usr/bin/env bash
# Build a deterministic ZIP of the cost-allocator Azure Function App from source.
#
# The platform stack's cost allocator consumes this package via
# `cost_allocator_function_package_path` (default
# `../_modules/cost-allocator/dist/function_app.zip`, relative to the platform
# stack). Azure Functions remote build (SCM_DO_BUILD_DURING_DEPLOYMENT=true)
# installs requirements.txt during deployment, so the package only needs the
# function source. The ZIP is reproducible (sorted entries, fixed timestamps) so
# Terraform does not detect spurious changes between builds.
#
# Usage: scripts/cost-allocator/package-function.sh [output_zip]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_dir="${repo_root}/infrastructure/terraform/_modules/cost-allocator/function_app"
output_zip="${1:-${repo_root}/infrastructure/terraform/_modules/cost-allocator/dist/function_app.zip}"

if [ ! -f "${source_dir}/function_app.py" ] || [ ! -f "${source_dir}/host.json" ] || [ ! -f "${source_dir}/requirements.txt" ]; then
  echo "::error::cost-allocator function source is incomplete under ${source_dir}" >&2
  exit 1
fi

mkdir -p "$(dirname "${output_zip}")"
rm -f "${output_zip}"

SOURCE_DIR="${source_dir}" OUTPUT_ZIP="${output_zip}" python3 - <<'PY'
import os
import zipfile

source_dir = os.environ["SOURCE_DIR"]
output_zip = os.environ["OUTPUT_ZIP"]
# Fixed timestamp keeps the archive byte-reproducible across builds.
fixed_date = (1980, 1, 1, 0, 0, 0)
excluded_dirs = {"__pycache__", ".pytest_cache", ".mypy_cache"}

members = []
for root, dirs, files in os.walk(source_dir):
    dirs[:] = sorted(d for d in dirs if d not in excluded_dirs)
    for name in sorted(files):
        if name.endswith((".pyc", ".pyo")):
            continue
        absolute = os.path.join(root, name)
        arcname = os.path.relpath(absolute, source_dir)
        members.append((absolute, arcname))

members.sort(key=lambda item: item[1])
with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for absolute, arcname in members:
        info = zipfile.ZipInfo(arcname, date_time=fixed_date)
        info.external_attr = 0o644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        with open(absolute, "rb") as handle:
            archive.writestr(info, handle.read())

print(f"packaged {len(members)} file(s) -> {output_zip}")
PY
