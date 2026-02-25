#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2026 fadlyas07 <mhmmdfdlyas@proton.me>

# Working directory
export DIR="$(pwd)"

# Specify the build flags for the scripts
if [[ "${1}" == final ]]; then
    export build_flags="--final"
elif ! [[ "${1}" == profile || "${1}" == final ]]; then
    echo "You need to set the correct arguments!"
    exit 1
fi

# Setup GitHub config and hooks
hooks_dir="${HOME}/.git/hooks"
mkdir -p "${hooks_dir}"
git config --global user.name "${ghuser_name}"
git config --global user.email "${ghuser_email}"
git config --global core.hooksPath "${hooks_dir}"
curl -s -Lo "${hooks_dir}/commit-msg" https://review.lineageos.org/tools/hooks/commit-msg
chmod u+x "${hooks_dir}/commit-msg"

# Export common environment variables
export PATH="/usr/bin/core_perl:${PATH}"
export cpu_core="$(nproc --all)"
export release_tag="$(date +'%Y%m%d')"     # "{year}{month}{date}" format
export release_date="$(date +'%-d %B %Y')" # "Day Month Year" format
export install_path="${DIR}/install"
export glibc_version="$(ldd --version | head -n1 | grep -oE '[^ ]+$')"

# Execute the build scripts
bash "${DIR}/tc_scripts/build.sh" "${1}"
