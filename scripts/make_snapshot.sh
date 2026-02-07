#!/bin/bash

# Exit on error
set -e

# Default tag if no arguments
DEFAULT_TAG="default-backup"

# Combine arguments into a single tag, or use default
if [ "$#" -ge 1 ]; then
    TAG="$*"
else
    TAG="$DEFAULT_TAG"
fi

# Restic environment
export RESTIC_REPOSITORY=/backups
export RESTIC_PASSWORD_FILE=/root/.restic-pass

# Backup with tag
restic backup / \
    --exclude-file /root/restic-excludes.txt \
    --one-file-system \
    --verbose \
    --tag "$TAG"

# Forget old backups
restic forget --prune \
    --keep-last 30

