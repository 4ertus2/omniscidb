target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v16:16:16-v32:32:32-v64:64:64-v128:128:128-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

declare i32 @llvm.nvvm.read.ptx.sreg.tid.x() readnone nounwind
declare i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() readnone nounwind
declare i32 @llvm.nvvm.read.ptx.sreg.ntid.x() readnone nounwind
declare i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() readnone nounwind

define i32 @pos_start_impl() {
  %threadIdx = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %blockIdx = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %blockDim = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %1 = mul nsw i32 %blockIdx, %blockDim
  %2 = add nsw i32 %threadIdx, %1
  ret i32 %2
}

define i32 @pos_step_impl() {
  %blockDim = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %gridDim = call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
  %1 = mul nsw i32 %blockDim, %gridDim
  ret i32 %1
}

; Function Attrs: uwtable
define void @kernel(i8** %byte_stream, i64* nocapture readonly %row_count_ptr, i64* nocapture readonly %agg_init_val, i64* nocapture %out) #3 {
  %1 = getelementptr i8** %byte_stream, i32 0
  %2 = load i8** %1
  %3 = load i64* %row_count_ptr, align 8
  %4 = load i64* %agg_init_val, align 8
  %5 = call i32 @pos_start_impl()
  %6 = call i32 @pos_step_impl()
  %7 = sext i32 %5 to i64
  %8 = icmp slt i64 %7, %3
  br i1 %8, label %.lr.ph, label %21

.lr.ph:                                           ; preds = %0
  %9 = sext i32 %6 to i64
  br label %10

; <label>:10                                      ; preds = %18, %.lr.ph
  %result.0 = phi i64 [ %4, %.lr.ph ], [ %result.1, %18 ]
  %pos.01 = phi i64 [ %7, %.lr.ph ], [ %19, %18 ]
  %11 = getelementptr inbounds i8* %2, i64 %pos.01
  %12 = load i8* %11, align 1
  %13 = sext i8 %12 to i64
  %14 = icmp sgt i64 %13, 41
  %15 = icmp eq i1 %14, 0
  br i1 %15, label %18, label %16

; <label>:16                                      ; preds = %10
  %17 = add nsw i64 %result.0, 1
  br label %18

; <label>:18                                      ; preds = %16, %10
  %result.1 = phi i64 [ %result.0, %10 ], [ %17, %16 ]
  %19 = add nsw i64 %pos.01, %9
  %20 = icmp slt i64 %19, %3
  br i1 %20, label %10, label %._crit_edge

._crit_edge:                                      ; preds = %18
  br label %21

; <label>:21                                      ; preds = %._crit_edge, %0
  %22 = phi i64 [ %result.1, %._crit_edge ], [ %4, %0 ]
  %23 = getelementptr inbounds i64* %out, i64 %7
  store i64 %22, i64* %23, align 8
  ret void
}


!nvvm.annotations = !{!0}
!0 = metadata !{void (i8**,
                      i64*,
                      i64*,
                      i64*)* @kernel, metadata !"kernel", i32 1}
