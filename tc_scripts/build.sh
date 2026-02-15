#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2025 fadlyas07 <mhmmdfdlyas@proton.me>

# Build LLVM
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
./build-llvm.py ${build_flags} \
    --defines LLVM_PARALLEL_COMPILE_JOBS="${cpu_core}" LLVM_PARALLEL_LINK_JOBS="${cpu_core}" \
    --build-stage1-only \
    --build-target distribution \
    --install-folder "${install_path}" \
    --install-target distribution \
    --projects clang lld polly \
    --llvm-folder "${DIR}/src/llvm-project" \
    --lto thin \
    --multicall \
    --pgo kernel-defconfig \
    --quiet-cmake \
    --targets ARM AArch64 X86 \
    --vendor-string "Android (Gf's C Compiler, +pgo, +bolt, +thinLTO, LLVM-based)" 2>&1 | tee "${llvm_log}"

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
