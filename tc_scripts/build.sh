#!/usr/bin/env bash
# ---- Clang Build Scripts ----
# Copyright (C) 2023-2026 fadlyas07 <mhmmdfdlyas@proton.me>

# Build LLVM
export llvm_log="${DIR}/build-llvm-${release_tag}.log"
./build-llvm.py ${build_flags} \
    --defines LLVM_OPTIMIZED_TABLEGEN=ON LLVM_INCLUDE_TESTS=OFF LLVM_INCLUDE_DOCS=OFF LLVM_INCLUDE_EXAMPLES=OFF LLVM_BUILD_TESTS=OFF LLVM_BUILD_EXAMPLES=OFF LLVM_BUILD_BENCHMARKS=OFF LLVM_ENABLE_BINDINGS=OFF LLVM_ENABLE_TERMINFO=OFF LLVM_ENABLE_ZSTD=ON LLVM_ENABLE_RTTI=OFF LLVM_ENABLE_EH=OFF CLANG_ENABLE_ARCMT=OFF CLANG_ENABLE_STATIC_ANALYZER=OFF LLVM_PARALLEL_COMPILE_JOBS="${cpu_core}" LLVM_PARALLEL_LINK_JOBS="4" LLVM_ENABLE_RUNTIMES="compiler-rt" LLVM_ENABLE_UNWIND_TABLES=OFF LLVM_ENABLE_BACKTRACES=OFF CMAKE_C_FLAGS="-march=native -O3 -pipe" CMAKE_CXX_FLAGS="-march=native -O3 -pipe" \
    --build-stage1-only \
    --build-target distribution \
    --install-folder "${install_path}" \
    --install-target distribution \
    --distribution-profile kernel \
    --projects clang lld polly compiler-rt \
    --llvm-folder "${DIR}/src/llvm-project" \
    --pgo kernel-defconfig \
    --bolt \
    --lto thin \
    --multicall \
    --quiet-cmake \
    --targets AArch64 ARM X86 \
    --vendor-string "Cirrus" \
    2>&1 | tee "${llvm_log}"

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
