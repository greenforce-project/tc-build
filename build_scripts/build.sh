#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2024 fadlyas07 <mhmmdfdlyas@proton.me>

# Inherit common function
source "${DIR}"/build_scripts/helper.sh

build_info "🔨 Greenforce Clang Build has Started!
Build Task: ${build_type}
Build Job: ${jobs_total} core CPUs
Build Date: $(date +'%Y-%m-%d %H:%M')"

# HACK: Manually clone the LLVM project repository for edit
if ! pushd "${DIR}/src/llvm-project"; then
    git clone -j"${jobs_total}" --single-branch -b "${llvm_branch}" https://github.com/llvm/llvm-project.git "${DIR}/src/llvm-project" || {
        kecho "Failed to clone the LLVM project repository!"
        kecho "Please check your server; it's likely that the repository exists."
        kecho ""
        kecho "Now you're at: $(pwd)"
        exit 1
    }
fi

# This merge changes '19.0.0git' to '19.0.0' in CLANG_VERSION
pushd "${DIR}/src/llvm-project" || exit 1
git fetch https://github.com/greenforce-project/llvm-project "${llvm_branch}" || exit 1
git merge FETCH_HEAD --no-commit || exit 1
popd || exit 1

# Build LLVM
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
build_info "Building clang LLVM..."
./build-llvm.py ${build_flags} \
    -D LLVM_PARALLEL_COMPILE_JOBS=${jobs_total} LLVM_PARALLEL_LINK_JOBS=${jobs_total} \
    -i "${install_path}" \
    -p clang lld \
    -n \
    -t AArch64 ARM X86 \
    --build-stage1-only \
    --build-target distribution \
    --build-type "Release" \
    --pgo llvm \
    --ref "${llvm_branch}" \
    --quiet-cmake \
    --vendor-string "greenforce" 2>&1 | tee "${llvm_log}"

kecho "Checking the final clang binary..."
for clang in "${DIR}"/install/bin/clang; do
    if ! [[ -f "${clang}" || -f "${DIR}"/build/llvm/instrumented/profdata.prof ]]; then
        kerror "Building clang LLVM failed kindly check errors!"
        telegram_file "${llvm_log}" "${tguser_chatid}" "Here is the LLVM error log."
        exit 1
    else
        kecho "Building LLVM success!"
        telegram_file "${llvm_log}" "${tguser_chatid}" "Here is the LLVM success log."
    fi
done

if [[ "${1}" == release ]]; then
    # Clone the binutils repository from the selected branch
    export binutils_path="${DIR}/src/binutils-${binutils_branch}"
    if ! pushd "${binutils_path}"; then
        git clone -j"${jobs_total}" --single-branch -b "${binutils_branch}" https://sourceware.org/git/binutils-gdb.git "${binutils_path}" --depth=1 || {
            kecho "Failed to clone the binutils repository!"
            kecho "Please check your server; it's likely that the repository exists."
            kecho ""
            kecho "Now you're at: $(pwd)"
            exit 1
        }
    fi

    # Build binutils
    build_info "Building binutils..."
    export binutils_log="${DIR}/build-binutils-${release_tag}.log"
    ./build-binutils.py \
        -B "${binutils_path}" \
        -i "${install_path}" \
        -t arm aarch64 x86_64 2>&1 | tee "${binutils_log}"

    kecho "Building binutils success!"
    telegram_file "${binutils_log}" "${tguser_chatid}" "Here is the binutils success log."

    # Remove unused products
    rm -fr "${install_path}"/include "${install_path}"/lib/cmake
    rm -f "${install_path}"/lib/*.a "${install_path}"/lib/*.la
    for package in "${DIR}"/src/*.tar.xz; do
        rm -rf "${package}" || exit 1
    done

    # Strip remaining products
    find "${install_path}" -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}' | while read -r f; do
        strip -s "${f: : -1}"
    done

    # Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
    find "${install_path}" -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}' | while read -r bin; do
        # Remove last character from file output (':')
        bin="${bin: : -1}"
        kecho "${bin}"
        patchelf --set-rpath "${install_path}/lib" "${bin}"
    done

    # Clone the catalogue repository
    if ! pushd "${DIR}/greenforce_clang"; then
        git clone -j"${jobs_total}" --single-branch -b main "https://${ghuser_name}:${ghuser_token}@github.com/greenforce-project/greenforce_clang" --depth=1 || {
            kecho "Failed to clone the catalogue repository!"
            kecho "Please check your server; it's likely that the repository exists."
            kecho ""
            kecho "Now you're at: $(pwd)"
            exit 1
        }
    fi

    # GitHub push environment
    pushd "${DIR}/src/llvm-project" || exit 1
    export lcommit_message="$(git log --pretty='format:%s' | head -n1)"
    export llvm_hash="$(git rev-parse --verify HEAD)"
    popd || exit 1
    pushd "${binutils_path}" || exit 1
    export bcommit_message="$(git log --pretty='format:%s' | head -n1)"
    export binutils_hash="$(git rev-parse --verify HEAD)"
    popd || exit 1
    export llvm_url="https://github.com/llvm/llvm-project/commit/${llvm_hash}"
    export binutils_url="https://github.com/bminor/binutils-gdb/commit/${binutils_hash}"
    export binutils_version="$(ls ${DIR}/src/ | grep "^binutils-" | sed "s/binutils-//g")"
    export clang_version="$(${install_path}/bin/clang --version | head -n1)"
    export short_clang="$(echo ${clang_version} | cut -d' ' -f4)"
    export lld_version="$(${install_path}/bin/ld.lld --version | cut -d' ' -f2-3)"
    export release_file="greenforce-clang-${short_clang}-${release_tag}-${release_time}.tar.zst"
    export release_info="clang-${short_clang}-${release_tag}-${release_time}-info.txt"
    export release_url="https://github.com/greenforce-project/greenforce_clang/releases/download/${release_tag}/${release_file}"

    # Package the clang release file
    pushd "${install_path}" || exit 1
    time tar -I'../build_scripts/zstd --ultra -22 -T0' -cf "${release_file}" ./*
    popd || exit 1

    export release_path="${install_path}/${release_file}"
    export release_shasum="$(sha256sum ${release_path} | awk '{print $1}')"
    export release_size="$(du -sh ${release_path} | awk '{print $1}')"

    touch /tmp/release_desc
    {
        echo "Clang Version: ${short_clang}"
        echo "Binutils version: ${binutils_version}"
        echo -e "LLD version: ${lld_version}\n"
        echo "LLVM commit: ${llvm_url}"
        echo "Binutils commit: ${binutils_url}"
    } > /tmp/release_desc

    # Push the commits and releases
    pushd "${DIR}/greenforce_clang" || exit 1
    bash "${DIR}"/build_scripts/info.sh
    echo "latest=${release_url}" > latest_link
    git add .
    git commit -s -m "[weekly]: Pull update from commit ${llvm_hash}" \
    -m "Tag: ${release_tag}" \
    -m "See the release files here https://github.com/greenforce-project/greenforce_clang/releases/tag/${release_tag}"
    git push "https://${ghuser_name}:${ghuser_token}@github.com/greenforce-project/greenforce_clang" main -f

    if gh release view "${release_tag}"; then
        kecho "Uploading build archive to '${release_tag}'..."
        gh release upload --clobber "${release_tag}" "${release_path}" && {
            kecho "Version ${release_tag} updated!"
        }
    else
        kecho "Creating release with tag '${release_tag}'..."
        gh release create "${release_tag}" -F /tmp/release_desc "${release_path}" -t "${release_date}" && {
            kecho "Version ${release_tag} released!"
        }
    fi

    git push "https://${ghuser_name}:${ghuser_token}@github.com/greenforce-project/greenforce_clang" main -f
    kecho "Push complete!"
    popd || exit 1

    MSG="<b>New Greenforce Clang update available!</b>

    <b>Host system details</b>
    Distro: <code>${distro_image}</code>
    Glibc version: <code>${glibc_version}</code>
    Clang version: <code>${dclang_version}</code>

    <b>Toolchain details</b>
    Clang version: <code>${short_clang}</code>
    Binutils version: <code>${binutils_version}</code>
    LLVM commit: <a href='${llvm_url}'>${lcommit_message}</a>
    Binutils commit: <a href='${binutils_url}'>${bcommit_message}</a>
    Build Date: <code>$(date +'%Y-%m-%d %H:%M')</code>
    Build Tag: <code>${release_tag}</code>

    <b>Build Release:</b> <a href='${release_url}'>${release_file}</a>"
    telegram_message "${MSG}"
fi
