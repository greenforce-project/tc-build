#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2024 fadlyas07 <mhmmdfdlyas@proton.me>

# Inherit common function
source "${DIR}"/build_scripts/helper.sh

# Remove existing files
kecho "Removing existing files..."
rm -rf "${README_path}" latest.txt

# Create latest.txt and populate it with release tag
kecho "Creating latest.txt..."
echo -e "[tag]\n${release_tag}" > latest.txt

# Create release info file and populate it with release information
kecho "Creating release_info file..."
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

touch /tmp/release_desc
{
    echo "Clang Version: ${short_clang}"
    echo "Binutils version: ${binutils_version}"
    echo -e "LLD version: ${lld_version}\n"
    echo "LLVM commit: ${llvm_url}"
    echo "Binutils commit: ${binutils_url}"
} > /tmp/release_desc

touch /tmp/telegram_post
{
    echo -e "<b>New Greenforce Clang update available!</b>\n"
    echo "<b>Host system details</b>"
    echo "Distro: <code>${distro_image}</code>"
    echo "Glibc version: <code>${glibc_version}</code>"
    echo -e "Clang version: <code>${dclang_version}</code>\n"
    echo "<b>Toolchain details</b>"
    echo "Clang version: <code>${short_clang}</code>"
    echo "Binutils version: <code>${binutils_version}</code>"
    echo "LLVM commit: <a href='${llvm_url}'>${lcommit_message}</a>"
    echo "Binutils commit: <a href='${binutils_url}'>${bcommit_message}</a>"
    echo "Build Date: <code>$(date +'%Y-%m-%d %H:%M')</code>"
    echo -e "Build Tag: <code>${release_tag}</code>\n"
    echo "<b>Build Release:</b> <a href='${release_url}'>${release_file}</a>"
} > /tmp/telegram_post

# Create README.md file and populate it with content
kecho "Creating README.md..."
touch "${README_path}"
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
    echo -e 'Optionally, you can also choose to use as many LLVM tools as possible to reduce reliance on binutils. All of these must be passed directly to `make`:\n'
    echo -e '- `AR=llvm-ar`'
    echo -e '- `NM=llvm-nm`'
    echo -e '- `OBJCOPY=llvm-objcopy`'
    echo -e '- `OBJDUMP=llvm-objdump`'
    echo -e '- `STRIP=llvm-strip`\n'
    echo -e 'Note, however, that additional kernel patches may be required for these LLVM tools to work. It is also possible to replace the binutils linkers (`lf.bfd` and `ld.gold`) with `lld` and use Clangs integrated assembler for inline assembly in C code, but that will require many more kernel patches and it is currently impossible to use the integrated assembler for *all* assembly code in the kernel.\n'
    echo -e "Android kernels older than 4.14 will require patches for compiling with any Clang toolchain to work; those patches are out of the scope of this project. See [android-kernel-clang](https://github.com/nathanchance/android-kernel-clang) for more information.\n"
    echo -e "### Differences from other toolchains\n"
    echo -e "Greenforce Clang has been designed to be easy-to-use compared to other toolchains, such as [AOSP Clang](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/). The differences are as follows:\n"
    echo -e '- `CLANG_TRIPLE` does not need to be set because we dont use AOSP binutils.'
    echo -e '- `LD_LIBRARY_PATH` does not need to be set because we set library load paths in the toolchain.'
    echo -e "- No separate GCC/binutils toolchains are necessary; all tools are bundled."
} > "${README_path}"

# Fixing typos and grammar
kecho "Fixing typos and grammar in README.md..."
sed -i "s/Clangs/Clang's/g" "${README_path}"
sed -i "s/dont/don't/g" "${README_path}"

kecho "Script execution completed successfully."
