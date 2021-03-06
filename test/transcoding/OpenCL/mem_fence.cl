// RUN: %clang_cc1 %s -triple spir -cl-std=CL1.2 -emit-llvm-bc -o %t.bc
// RUN: llvm-spirv %t.bc -o %t.spv
// RUN: spirv-val %t.spv
// RUN: llvm-spirv %t.spv -to-text -o - | FileCheck %s --check-prefix=CHECK-SPIRV
// RUN: llvm-spirv %t.spv -r --spirv-target-env=CL1.2 -o - | llvm-dis -o - | FileCheck %s --check-prefix=CHECK-LLVM

// This test checks that the translator is capable to correctly translate
// mem_fence OpenCL C 1.2 built-in function [1] into corresponding SPIR-V
// instruction and vice-versa.
//
// Forward declarations and defines below are based on the following sources:
// - llvm/llvm-project [2]:
//   - clang/lib/Headers/opencl-c-base.h
//   - clang/lib/Headers/opencl-c.h
// - OpenCL C 1.2 reference pages [1]
// TODO: remove these and switch to using -fdeclare-opencl-builtins once
// mem_fence is supported by this flag

typedef unsigned int cl_mem_fence_flags;

#define CLK_LOCAL_MEM_FENCE 0x01
#define CLK_GLOBAL_MEM_FENCE 0x02
// Strictly speaking, this flag is not supported by mem_fence in OpenCL 1.2
#define CLK_IMAGE_MEM_FENCE 0x04

void __attribute__((overloadable)) mem_fence(cl_mem_fence_flags);

__kernel void test_mem_fence_const_flags() {
  mem_fence(CLK_LOCAL_MEM_FENCE);
  mem_fence(CLK_GLOBAL_MEM_FENCE);
  mem_fence(CLK_IMAGE_MEM_FENCE);

  mem_fence(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE);
  mem_fence(CLK_LOCAL_MEM_FENCE | CLK_IMAGE_MEM_FENCE);
  mem_fence(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE | CLK_IMAGE_MEM_FENCE);
}

__kernel void test_mem_fence_non_const_flags(cl_mem_fence_flags flags) {
  // FIXME: OpenCL spec doesn't require flags to be compile-time known
  // mem_fence(flags);
}

// CHECK-SPIRV: EntryPoint {{[0-9]+}} [[TEST_CONST_FLAGS:[0-9]+]] "test_mem_fence_const_flags"
// CHECK-SPIRV: TypeInt [[UINT:[0-9]+]] 32 0
//
// In SPIR-V, mem_fence is represented as OpMemoryBarrier [3] and OpenCL
// cl_mem_fence_flags are represented as part of Memory Semantics [4], which
// also includes memory order constraints. The translator applies some default
// memory order for OpMemoryBarrier and therefore, constants below include a
// bit more information than original source
//
// 0x2 Workgroup
// CHECK-SPIRV-DAG: Constant [[UINT]] [[WG:[0-9]+]] 2
//
// 0x0 Relaxed + 0x100 WorkgroupMemory
// CHECK-SPIRV-DAG: Constant [[UINT]] [[LOCAL:[0-9]+]] 256
// 0x0 Relaxed + 0x200 CrossWorkgroupMemory
// CHECK-SPIRV-DAG: Constant [[UINT]] [[GLOBAL:[0-9]+]] 512
// 0x0 Relaxed + 0x800 ImageMemory
// CHECK-SPIRV-DAG: Constant [[UINT]] [[IMAGE:[0-9]+]] 2048
// 0x0 Relaxed + 0x100 WorkgroupMemory + 0x200 CrossWorkgroupMemory
// CHECK-SPIRV-DAG: Constant [[UINT]] [[LOCAL_GLOBAL:[0-9]+]] 768
// 0x0 Relaxed + 0x100 WorkgroupMemory + 0x800 ImageMemory
// CHECK-SPIRV-DAG: Constant [[UINT]] [[LOCAL_IMAGE:[0-9]+]] 2304
// 0x0 Relaxed + 0x100 WorkgroupMemory + 0x200 CrossWorkgroupMemory + 0x800 ImageMemory
// CHECK-SPIRV-DAG: Constant [[UINT]] [[LOCAL_GLOBAL_IMAGE:[0-9]+]] 2816
//
// CHECK-SPIRV: Function {{[0-9]+}} [[TEST_CONST_FLAGS]]
// CHECK-SPIRV: MemoryBarrier [[WG]] [[LOCAL]]
// CHECK-SPIRV: MemoryBarrier [[WG]] [[GLOBAL]]
// CHECK-SPIRV: MemoryBarrier [[WG]] [[IMAGE]]
// CHECK-SPIRV: MemoryBarrier [[WG]] [[LOCAL_GLOBAL]]
// CHECK-SPIRV: MemoryBarrier [[WG]] [[LOCAL_IMAGE]]
// CHECK-SPIRV: MemoryBarrier [[WG]] [[LOCAL_GLOBAL_IMAGE]]
//
// CHECK-LLVM-LABEL: define spir_kernel void @test_mem_fence_const_flags
// CHECK-LLVM: call spir_func void @_Z9mem_fencej(i32 1)
// CHECK-LLVM: call spir_func void @_Z9mem_fencej(i32 2)
// CHECK-LLVM: call spir_func void @_Z9mem_fencej(i32 4)
// CHECK-LLVM: call spir_func void @_Z9mem_fencej(i32 3)
// CHECK-LLVM: call spir_func void @_Z9mem_fencej(i32 5)
// CHECK-LLVM: call spir_func void @_Z9mem_fencej(i32 7)

// References:
// [1]: https://www.khronos.org/registry/OpenCL/sdk/1.2/docs/man/xhtml/mem_fence.html
// [2]: https://github.com/llvm/llvm-project
// [3]: https://www.khronos.org/registry/spir-v/specs/unified1/SPIRV.html#OpMemoryBarrier
// [4]: https://www.khronos.org/registry/spir-v/specs/unified1/SPIRV.html#_a_id_memory_semantics__id_a_memory_semantics_lt_id_gt
