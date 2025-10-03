#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2025 fadlyas07 <mhmmdfdlyas@proton.me>

echo -e "[tag]\n${release_tag}" >latest.txt
release_url="https://github.com/greenforce-project/greenforce_clang/releases/download/${release_tag}/${release_file}"
touch "clang_notes.txt"
{
    echo -e "[date]\n${release_date}\n"
    echo -e "[clang-ver]\n${clang_version}\n"
    echo -e "[lld-ver]\n${lld_version}\n"
    echo -e "[llvm-commit]\n${llvm_url}\n"
    echo -e "[llvm-commit-msg]\n${lcommit_message}\n"
    echo -e "[host-glibc]\n${glibc_version}\n"
    echo -e "[size]\n${release_size}\n"
    echo -e "[link-rel]\n${release_url}\n"
    echo -e "[shasum]\n${release_shasum}"
} >"clang_notes.txt"

touch /tmp/commit_msg
{
    echo -e "CI: Bump to ${release_tag} build\n"
    echo "Clang version: ${clang_version}"
    echo "LLVM repo commit: ${lcommit_message}"
    echo "Link: ${llvm_url}"
} >/tmp/commit_msg

touch get_latest_url.sh
{
    echo -e "#!/usr/bin/env bash\n"
    echo "LATEST_URL=${release_url}"
} >get_latest_url.sh
