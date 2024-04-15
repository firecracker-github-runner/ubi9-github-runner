#!/bin/env bash

set -eoux pipefail

function fetch {
  local package=$1
  local filename_prefix=$2

  local releases_api=https://api.github.com/repos/${package}/releases/latest
  local tag=$(curl -sSLf -H 'Accept: application/json' ${releases_api} | jq -r '.tag_name')
  local artifact=${filename_prefix}_${tag:1}_linux_x86_64
  local url=https://github.com/${package}/releases/download/${tag}/${artifact}.tar.gz

  mkdir -p ${filename_prefix}

  curl -sSLf -O $url
  tar fxzp ${artifact}.tar.gz -C ${filename_prefix}
  rm ${artifact}.tar.gz

  mv ${filename_prefix}/${filename_prefix} ${BIN_OUT}/${filename_prefix}
}

fetch "ko-build/ko" "ko"
