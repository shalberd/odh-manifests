#!/usr/bin/env bash

# This script is used to fetch KServe manifests from github.com/opendatahub-io/kserve
# and bundles them into one big assembled `kserve-built-yaml` file.
# To update the version, update `hack/kustomization.yaml` and re-run the script with:
#
# $ hack/build-kserve-manifests.sh

set -Eeuo pipefail

echo "Building KServe manifests"
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
output_dir="$script_dir/../kserve-built"

command -v kustomize >/dev/null 2>&1 || echo >&2 "kustomize is not installed. Please install kustomize in order to proceed"

kustomize build "$script_dir" > "$output_dir"/kserve-built.yaml

echo "KServe manifests fetched from upstream and assembled into $output_dir/kserve-built.yaml"
