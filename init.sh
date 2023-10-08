#!/usr/bin/env bash
# ---- Clang Build Script ----
# Copyright (C) 2023 fadlyas07 <mhmmdfdlyas@proton.me>

# Working dir
export DIR="$(pwd)"

# Inherit function from other file
source "${DIR}"/function.sh

# Specify build type for script
case "${1}" in
    ccache)
        export build_flags=
        export build_type="Collect ccache"
    ;;
    release)
        export build_flags="--final"
        export build_type="Build release"
    ;;
    *)
        kerror "Need to specify build type!"
        exit 1
    ;;
esac

# Setup git.config and git hooks for commit
mkdir -p ~/.git/hooks
git config --global user.name "${ghuser_name}"
git config --global user.email "${ghuser_email}"
git config --global http.postBuffer 524288000
gh auth login --with-token <<< "${ghuser_token}"
git config --global core.hooksPath ~/.git/hooks
curl -Lo ~/.git/hooks/commit-msg https://review.lineageos.org/tools/hooks/commit-msg
chmod u+x ~/.git/hooks/commit-msg

# Export common environment variable
export PATH="/usr/bin/core_perl:${PATH}"
export release_tag="$(date +'%d%m%Y')"     # "{date}{month}{year}" format
export release_time="$(date +'%H%M')"      # HoursMinute
export release_date="$(date +'%-d %B %Y')" # "Day Month Year" format
export install_path="${DIR}/install"

# Execute build scripts
./clang-build.sh "${1}"
