#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2024 fadlyas07 <mhmmdfdlyas@proton.me>

# Build LLVM
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
./build-llvm.py ${build_flags} \
    --bolt \
    --build-stage1-only \
    --build-target distribution \
    --install-folder "${install_path}" \
    --install-target distribution \
    --projects clang lld \
    --llvm-folder "${DIR}/src/llvm-project" \
    --lto thin \
    --pgo llvm \
    --quiet-cmake \
    --targets ARM AArch64 X86 \
    --vendor-string "greenforce" 2>&1 | tee "${llvm_log}"

for clang in "${install_path}"/bin/clang; do
    if ! [[ -f "${clang}" || -f "${DIR}/build/llvm/instrumented/profdata.prof" ]]; then
        echo "Building Clang LLVM failed kindly check errors!"
        exit 1
    fi
done

# Execute the push scripts if on the `final` step
if [[ "${1}" == final ]]; then
    bash "${DIR}/tc_scripts/push.sh"
fi
