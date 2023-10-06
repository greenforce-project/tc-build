#!/usr/bin/env bash
# ---- Clang Build Script ----
# Copyright (C) 2023 fadlyas07 <mhmmdfdlyas@proton.me>

source "${DIR}"/function.sh

build_info "🔨 Greenforce Clang Build Started!
Build Task: ${build_type}
Build Date: $(date +'%Y-%m-%d %H:%M')"

# Function to push github tags and release
function push_rtag() {
    chmod +x "${DIR}/ghrelease_tools"
    ./ghrelease_tools release \
        --security-token "${ghuser_token}" \
        --user "greenforce-project" \
        --repo "greenforce_clang" \
        --tag "${release_tag}" \
        --name "${release_date}" \
        --description "${commit_message}" || echo "Tag already exists!"
}

function push_rfile() {
    chmod +x "${DIR}/ghrelease_tools"
    ./ghrelease_tools upload \
        --security-token "${ghuser_token}" \
        --user "greenforce-project" \
        --repo "greenforce_clang" \
        --tag "${release_tag}" \
        --name "${release_file}" \
        --file "${release_path}" || echo "Failed to push files!"
}

# Build start
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
jobs_total="$(($(nproc --all)*4))"
start_time="$(date +'%s')"
./build-llvm.py ${build_flags} \
    --build-type "Release" \
    --build-stage1-only \
    --defines LLVM_PARALLEL_COMPILE_JOBS=${jobs_total} LLVM_PARALLEL_LINK_JOBS=${jobs_total} CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 CMAKE_C_FLAGS='-march=native -mtune=native' CMAKE_CXX_FLAGS='-march=native -mtune=native' \
    --install-folder "${install_path}" \
    --pgo llvm \
    --projects clang lld polly \
    --shallow-clone \
    --targets ARM AArch64 X86 \
    --vendor-string "greenforce" \
    --quiet-cmake 2>&1 | tee "${llvm_log}"

kecho "Checking if the final clang binary exists or not..."
for clang in "${DIR}"/install/bin/clang; do
    if ! [[ -f "${clang}" || -f "${DIR}/build/llvm/instrumented/profdata.prof" ]]; then
        kerror "Building LLVM failed kindly check errors!"
        telegram_file "${llvm_log}" "${tguser_chatid}" "LLVM error Log."
        exit 1
    else
        kecho "Building LLVM success!"
        telegram_file "${llvm_log}" "${tguser_chatid}" "LLVM success Log."
    fi
done

if [[ "${1}" == release ]]; then

# Build binutils
build_info "Building binutils..."
export binutils_log="${DIR}/build-binutils-${release_tag}.log"
./build-binutils.py \
    -t arm aarch64 x86_64 \
    -m native \
    -i "${install_path}" 2>&1 | tee "${binutils_log}"

kecho "Building binutils success!"
telegram_file "${binutils_log}" "${tguser_chatid}" "Binutils success Log."

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

if ! pushd "${DIR}/greenforce_clang"; then       # default is empty
    kecho "Cloning catalogue repository..."
    git clone -q -j64 --single-branch -b main https://fadlyas07:${ghuser_token}@github.com/greenforce-project/greenforce_clang --depth=1
    kecho "done!"
else
    kecho "catalogue repository exist! [$(pwd)]"
    popd || exit 1
fi

# GitHub release environment
pushd "${DIR}/src/llvm-project" || exit 1
if [[ -e hash_tracking ]] ; then
    source hash_tracking
    export lcommit_message llvm_hash
else
    export lcommit_message="$(git log --pretty='format:%s' | head -n1)"
    export llvm_hash="$(git rev-parse --verify HEAD)"
fi
export short_hash="$(echo ${llvm_hash} | cut -c1-8)"
popd || exit 1

export llvm_url="https://github.com/greenforce-project/llvm-project/commit/${short_hash}"
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
export commit_message="Clang Version: ${short_clang}
Binutils version: ${binutils_version}

LLVM commit: ${llvm_url}
Release: https://github.com/greenforce-project/greenforce_clang/releases/tag/${release_tag}"

# Push catalogue commit and release
pushd "${DIR}/greenforce_clang" || exit 1
kecho "Generating build release info..."
echo -e "[tag]\n${release_tag}" > latest.txt
touch "${release_info}"
{
    echo -e "[date]\n${release_date}\n"
    echo -e "[clang-ver]\n${clang_version}\n"
    echo -e "[llvm-commit]\n${llvm_url}\n"
    echo -e "[llvm-commit-msg]\n${lcommit_message}\n"
    echo -e "[binutils-ver]\n${binutils_version}\n"
    echo -e "[host-glibc]\n${glibc_version}\n"
    echo -e "[size]\n${release_size}\n"
    echo -e "[shasum]\n${release_shasum}"
} > "${release_info}"
kecho "done!"
kecho "Generating README.md..."
[[ -e "${DIR}/README.md" ]] && rm -rf "${DIR}/README.md"
touch "README.md"
{
    echo -e "# Greenforce Clang\n"
    echo -e "To get started with Greenforce Clang, you'll need to get familiar with [Building Linux with Clang/LLVM](https://docs.kernel.org/kbuild/llvm.html).\n"
    echo -e "This is how you start initializing the Greenforce Clang to your server, use a command like this:\n"
    echo -e '```bash'
    echo -e "# Create a directory for the source files"
    echo -e "mkdir -p ~/toolchains/greenforce-clang"
    echo -e '```\n'
    echo -e "Then to download & extract:\n"
    echo -e '```bash'
    echo -e "wget -c ${release_url} -O - | tar --use-compress-program=unzstd -xf - -C ~/toolchains/greenforce-clang\n"
    echo -e '```\n'
    echo -e "You can see the major changes each week in ${release_info}.\n"
    echo -e "## Host compatibility\n"
    echo -e "This toolchain is built on ${distro_image}, which uses glibc ${glibc_version}. Compatibility with older distributions cannot be guaranteed. Other libc implementations (such as musl) are not supported.\n"
    echo -e "## Building Linux\n"
    echo -e 'Make sure you have this toolchain in your `PATH`:\n'
    echo -e '```bash\n'
    echo -e 'export PATH="~/toolchains/greenforce-clang/bin:$PATH"\n'
    echo -e '```\n'
    echo -e 'For an AArch64 cross-compilation setup, you must set the following variables. Some of them can be environment variables, but some must be passed directly to `make` as a command-line argument. It is recommended to pass **all** of them as `make` arguments to avoid confusing errors:\n'
    echo -e '- `CC=clang` (must be passed directly to `make`)'
    echo -e '- `CROSS_COMPILE=aarch64-linux-gnu-`'
    echo -e '- If your kernel has a 32-bit vDSO: `CROSS_COMPILE_ARM32=arm-linux-gnueabi-`\n'
    echo -e 'Optionally, you can also choose to use as many LLVM tools as possible to reduce reliance on binutils. All of these must be passed directly to `make`:\n'
    echo -e '- `AR=llvm-ar`'
    echo -e '- `NM=llvm-nm`'
    echo -e '- `OBJCOPY=llvm-objcopy`'
    echo -e '- `OBJDUMP=llvm-objdump`'
    echo -e '- `STRIP=llvm-strip`\n'
    echo -e 'Note, however, that additional kernel patches may be required for these LLVM tools to work. It is also possible to replace the binutils linkers (`lf.bfd` and `ld.gold`) with `lld` and use Clangs integrated assembler for inline assembly in C code, but that will require many more kernel patches and it is currently impossible to use the integrated assembler for *all* assembly code in the kernel.\n'
    echo -e "Android kernels older than 4.14 will require patches for compiling with any Clang toolchain to work; those patches are out of the scope of this project. See [android-kernel-clang](https://github.com/nathanchance/android-kernel-clang) for more information.\n"
    echo -e 'Android kernels 4.19 and newer use the upstream variable `CROSS_COMPILE_COMPAT`. When building these kernels, replace `CROSS_COMPILE_ARM32` in your commands and scripts with `CROSS_COMPILE_COMPAT`.\n'
    echo -e "### Differences from other toolchains\n"
    echo -e "Greenforce Clang has been designed to be easy-to-use compared to other toolchains, such as [AOSP Clang](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/). The differences are as follows:\n"
    echo -e '- `CLANG_TRIPLE` does not need to be set because we dont use AOSP binutils.'
    echo -e '- `LD_LIBRARY_PATH` does not need to be set because we set library load paths in the toolchain.'
    echo -e "- No separate GCC/binutils toolchains are necessary; all tools are bundled."
} > "README.md"
sed -i "s/Clangs/Clang's/g" README.md
sed -i "s/dont/don't/g" README.md

if [[ $(cat README.md) != "" ]]; then
    kecho "done!"
else
    kerror "Generating README.md failed kindly check errors!"
fi

git add .
git commit -m "[weekly][${release_tag}]: Pull greenforce clang update from commit ${llvm_hash}" -m "${commit_message}" --signoff
git push -fu origin main
popd || exit 1

# Check whether the releases was pushed or not
if [[ $(push_rtag) == "Tag already exists!" ]]; then
    kecho "[Tags] Triggering the function once again..."
    push_rtag || kecho "[Warn] Tag maybe already exist!"
fi

if [[ $(push_rfile) == "Failed to push files!" ]]; then
    kecho "[File] Triggering the function once again..."
    push_rfile || kerror "[Fatal] failed to push ${release_file} to git release!"
fi

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
