// RUN: %clang_cc1 %s -triple spir -cl-std=CL2.0 -emit-llvm-bc -o %t.bc

// RUN: llvm-spirv %t.bc -o %t.spv
// RUN: spirv-val %t.spv
// RUN: llvm-spirv %t.spv -to-text -o - | FileCheck %s --check-prefix=CHECK-SPIRV
// RUN: llvm-spirv %t.spv -r -o - | llvm-dis -o - | FileCheck %s --check-prefix=CHECK-LLVM

// Taken from clang/lib/Headers/opencl-c{,-base}.h
// TODO: remove these and switch to -fdeclare-opencl-builtins
typedef unsigned int uint4 __attribute__((ext_vector_type(4)));
uint4 __attribute__((overloadable)) get_sub_group_gt_mask(void);

// CHECK-SPIRV: Capability GroupNonUniformBallot
// CHECK-SPIRV: Decorate {{[0-9]+}} BuiltIn 4418

// CHECK-LLVM: test_mask
// CHECK-LLVM: call spir_func <4 x i32> @_Z21get_sub_group_gt_maskv()

kernel void test_mask(global uint4 *out)
{
  *out = get_sub_group_gt_mask();
}
