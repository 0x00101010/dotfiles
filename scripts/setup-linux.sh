#!/bin/sh
# Legacy entry point. install.sh is the supported bootstrap for macOS and Linux.
exec sh "$(dirname "$0")/../install.sh" "$@"
