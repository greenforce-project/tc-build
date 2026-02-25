#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2026 fadlyas07 <mhmmdfdlyas@proton.me>

# Build LLVM
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
./build-llvm.py ${build_flags} \
  --llvm-folder "${DIR}/src/llvm-project" \
  --targets ARM AArch64 X86 \
  --projects clang lld polly \
  --vendor-string "Android (Gf's C Compiler, LLVM-based)" \
  --defines LLVM_PARALLEL_COMPILE_JOBS="${cpu_core}" LLVM_PARALLEL_LINK_JOBS="${cpu_core}" \
  --pgo kernel-defconfig \
  --lto full \
  --bolt \
  --multicall \
  --build-stage1-only \
  --build-targets distribution \
  --install-folder "${install_path}" \
  --quiet-cmake 2>&1 | tee "${llvm_log}"

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
