#!/usr/bin/env bash
# ---- Clang Build Script ----
# Copyright (C) 2023 fadlyas07 <mhmmdfdlyas@proton.me>

# Inherit common function
source "${DIR}"/function.sh

rm -rf README.md latest.txt
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

touch "README.md"
{
    echo -e "# Greenforce Clang\n"
    echo -e "## Host compatibility\n"
    echo -e "This toolchain is built on ${distro_image}, which uses glibc ${glibc_version}. Compatibility with older distributions cannot be guaranteed. Other libc implementations (such as musl) are not supported.\n"
    echo -e "## Building Linux\n"
    echo -e "This is how you start initializing the Greenforce Clang to your server, use a command like this:\n"
    echo -e '```bash'
    echo -e "# Create a directory for the source files"
    echo -e "mkdir -p ~/toolchains/greenforce-clang"
    echo -e '```\n'
    echo -e "Then to download:\n"
    echo -e '```bash'
    echo -e "wget -c ${release_url} -O - | tar --use-compress-program=unzstd -xf - -C ~/toolchains/greenforce-clang\n"
    echo -e '```\n'
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
