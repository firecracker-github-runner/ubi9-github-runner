#!/usr/bin/env bash

set -euo pipefail

# A shim for sudo that just executes using the original username
# This is a hack for some github actions that use sudo internally
# NOTE: If sudo is actually needed, it will still obviously fail
echo "WARNING: invoking command as original user (NO SUDO)"
exec "$@"
