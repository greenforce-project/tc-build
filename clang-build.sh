#!/usr/bin/env bash
# ---- Clang Build Script ----
# Copyright (C) 2023 fadlyas07 <mhmmdfdlyas@proton.me>

# Inherit common function
source "${DIR}"/function.sh

build_info "🔨 Greenforce Clang Build Started!
Build Task: ${build_type}
Build Date: $(date +'%Y-%m-%d %H:%M')"

# Build start
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
jobs_total="$(nproc --all)"
start_time="$(date +'%s')"
./build-llvm.py ${build_flags} \
    -D LLVM_PARALLEL_COMPILE_JOBS=${jobs_total} LLVM_PARALLEL_LINK_JOBS=${jobs_total} CMAKE_C_FLAGS='-march=native -mtune=native' CMAKE_CXX_FLAGS='-march=native -mtune=native' \
    -i "${install_path}" \
    -p clang compiler-rt lld polly \
    -s \
    -t AArch64 ARM X86 \
    --build-stage1-only \
    --build-type "Release" \
    --pgo llvm \
    --ref "${llvm_branch}" \
    --quiet-cmake \
    --vendor-string "greenforce" 2>&1 | tee "${llvm_log}"

kecho "Checking the final clang binary..."
for clang in "${DIR}"/install/bin/clang; do
    if ! [[ -f "${clang}" || -f "${DIR}/build/llvm/instrumented/profdata.prof" ]]; then
        kerror "Building clang LLVM failed, kindly check errors!"
        telegram_file "${llvm_log}" "${tguser_chatid}" "Build LLVM errors Log."
        exit 1
    else
        kecho "Building LLVM success!"
        telegram_file "${llvm_log}" "${tguser_chatid}" "Build LLVM success Log."
    fi
done

if [[ "${1}" == release ]]; then

# Build binutils
build_info "Building binutils..."
export binutils_log="${DIR}/build-binutils-${release_tag}.log"
export binutils_path="${DIR}/src/binutils-${binutils_branch}"

# Clone the binutils source from selective branch
if ! pushd "${binutils_path}"; then
    git clone -j"${jobs_total}" --single-branch -b "${binutils_branch}" https://sourceware.org/git/binutils-gdb.git "${binutils_path}" --depth=1
else
    kecho "Clone the binutils source failed!"
    kecho "Please check your server probably the source exist!"
    kecho "Current dir: $(pwd)"
    popd || exit 1
fi

./build-binutils.py \
    -B "${binutils_path}" \
    -i "${install_path}" \
    -m native \
    -t arm aarch64 x86_64 2>&1 | tee "${binutils_log}"

kecho "Building Binutils success!"
telegram_file "${binutils_log}" "${tguser_chatid}" "Build Binutils success Log."

# Build end
end_time="$(date +'%s')"
diff_time="$((end_time - start_time))"
export message_time="$((diff_time / 60)) mins, $((BUID_DIFF % 60)) secs."
kecho "Build complete: ${message_time}"

# Remove unused products
rm -fr "${install_path}/include" "${install_path}/lib/cmake"
rm -f "${install_path}"/lib/*.a "${install_path}"/lib/*.la
for package in "${DIR}"/src/*.tar.xz; do
    rm -rf "${package}"
done

# Strip remaining products
for f in $(find "${install_path}" -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
    strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find "${install_path}" -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
    # Remove last character from file output (':')
    bin="${bin: : -1}"

    kecho "${bin}"
    patchelf --set-rpath "${install_path}/lib" "${bin}"
done

if ! pushd "${DIR}/greenforce_clang"; then
    git clone -j"${jobs_total}" --single-branch -b main https://${ghuser_name}:${ghuser_token}@github.com/greenforce-project/greenforce_clang --depth=1
else
    kecho "Clone the catalogue repository failed!"
    kecho "Please check your server probably the repository exist!"
    kecho "Current dir: $(pwd)"
    popd || exit 1
fi

# Common push environment
pushd "${DIR}/src/llvm-project" || exit 1
export lcommit_message="$(git log --pretty='format:%s' | head -n1)"
export llvm_hash="$(git rev-parse --verify HEAD)"
export short_hash="$(echo ${llvm_hash} | cut -c1-8)"
popd || exit 1

export llvm_url="https://github.com/llvm/llvm-project/commit/${short_hash}"
export binutils_version="$(ls ${DIR}/src/ | grep "^binutils-" | sed "s/binutils-//g")"
export clang_version="$(${install_path}/bin/clang --version | head -n1)"
export short_clang="$(echo ${clang_version} | cut -d' ' -f4)"
export release_file="greenforce-clang-${short_clang}-${release_tag}-${release_time}.tar.zst"
export release_info="clang-${short_clang}-${release_tag}-${release_time}-info.txt"
export release_url="https://github.com/greenforce-project/greenforce_clang/releases/download/${release_tag}/${release_file}"

# Tar clang release file
pushd "${install_path}" || exit 1
time tar -I'../zstd --ultra -22 -T0' -cf "${release_file}" ./*
popd || exit 1

export release_path="${install_path}/${release_file}"
export release_shasum="$(sha256sum ${release_path} | awk '{print $1}')"
export release_size="$(du -sh ${release_path} | awk '{print $1}')"
export distro_image="$(source /etc/os-release && echo ${PRETTY_NAME})"
export glibc_version="$(ldd --version | head -n1 | grep -oE '[^ ]+$')"
export dclang_version="$(clang --version | head -n1 | grep -oE '[^ ]+$')"

# Push commits and releases
pushd "${DIR}/greenforce_clang" || exit 1
bash "${DIR}"/readme.sh
echo "latest=${release_url}" > latest_link
git add .
git commit -m "[weekly][${release_tag}]: Pull update from commit ${short_hash}

Clang Version: ${short_clang}
Binutils version: ${binutils_version}

LLVM commit: ${llvm_url}
Release: https://github.com/greenforce-project/greenforce_clang/releases/tag/${release_tag}"  --signoff
git push "https://${ghuser_name}:${ghuser_token}@github.com/greenforce-project/greenforce_clang" main -f

if gh release view "${release_tag}"; then
    kecho "Uploading build archive to '${release_tag}'..."
    gh release upload --clobber "${release_tag}" "${release_path}" && {
        kecho "Version ${release_tag} updated!"
    }
else
    kecho "Creating release with tag '${release_tag}'..."
    gh release create "${release_tag}" "${release_path}" -t "${release_date}" && {
        kecho "Version ${release_tag} released!"
    }
fi

git push "https://${ghuser_name}:${ghuser_token}@github.com/greenforce-project/greenforce_clang" main -f
kecho "push complete"
popd || exit 1

MSG="<b>New Greenforce Clang Update!</b>

<b>Toolchain details</b>
Clang version: <code>${short_clang}</code>
Binutils version: <code>${binutils_version}</code>
LLVM commit: <a href='${llvm_url}'>${lcommit_message}</a>
Build Date: <code>$(date +'%Y-%m-%d %H:%M')</code>
Build Tag: <code>${release_tag}</code>

<b>Host system details</b>
Distro: <code>${distro_image}</code>
Glibc version: <code>${glibc_version}</code>
Clang version: <code>${dclang_version}</code>

Build time: <code>${message_time}</code>
<b>Build Release:</b> <a href='${release_url}'>${release_file}</a>"

telegram_message "${MSG}"

fi
