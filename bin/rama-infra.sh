#!/bin/bash

set -eo pipefail

usage () {
  echo "Usage: rama-infra.sh <admin|user>"
  exit 2
}

[[ $# -eq 1 ]] || usage

APPLY_ROLE=$1
ROOT_DIR=$(pwd)
TF_DIR="${ROOT_DIR}"/aws-deploy/rama-infra/"${APPLY_ROLE}"

pushd "${TF_DIR}" || usage

WORKSPACE_NAME=infra-"${APPLY_ROLE}"

terraform workspace select "${WORKSPACE_NAME}" &> /dev/null || terraform workspace new "${WORKSPACE_NAME}"
terraform init
terraform apply

popd
