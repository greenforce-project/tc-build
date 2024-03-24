#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2024 fadlyas07 <mhmmdfdlyas@proton.me>

# Working directory
export DIR="$(pwd)"

# Inherit common function
source "${DIR}"/build_scripts/helper.sh

# Specify the build type for the script
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

# Setup git.config and hooks
mkdir -p ~/.git/hooks
git config --global user.name "${ghuser_name}"
git config --global user.email "${ghuser_email}"
git config --global http.postBuffer 524288000
gh auth login --with-token <<< "${ghuser_token}"
git config --global pull.rebase false
git config --global core.hooksPath ~/.git/hooks
curl -Lo ~/.git/hooks/commit-msg https://review.lineageos.org/tools/hooks/commit-msg
chmod u+x ~/.git/hooks/commit-msg

# Export common environment variables
export PATH="/usr/bin/core_perl:${PATH}"
export jobs_total="$(nproc --all)"
export release_tag="$(date +'%d%m%Y')"     # "{date}{month}{year}" format
export release_time="$(date +'%H%M')"      # HoursMinute
export release_date="$(date +'%-d %B %Y')" # "Day Month Year" format
export install_path="${DIR}/install"
export distro_image="$(source /etc/os-release && echo ${PRETTY_NAME})"
export glibc_version="$(ldd --version | head -n1 | grep -oE '[^ ]+$')"
export dclang_version="$(clang --version | head -n1 | grep -oE '[^ ]+$')"

# Execute the build scripts
./build_scripts/build.sh "${1}"
