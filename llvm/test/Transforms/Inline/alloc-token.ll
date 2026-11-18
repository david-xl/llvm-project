; RUN: opt < %s -passes='cgscc(inline)' -S | FileCheck %s

declare ptr @malloc(i64)
declare ptr @helper()

define internal ptr @wrapper(i64 %size) alwaysinline {
  ; Not returned: must not inherit the token.
  %h = call ptr @helper()
  %p = call ptr @malloc(i64 %size)
  ret ptr %p
}

; CHECK-LABEL: define ptr @inherits(
; CHECK: call ptr @helper(){{$}}
; CHECK: call ptr @malloc(i64 4){{.*}}, !alloc_token [[MD:![0-9]+]]
define ptr @inherits() {
  %c = call ptr @wrapper(i64 4), !alloc_token !0
  ret ptr %c
}

define internal ptr @wrapper_own(i64 %size) alwaysinline {
  %p = call ptr @malloc(i64 %size), !alloc_token !1
  ret ptr %p
}

; The call site sees more context, so its token overrides the wrapper's.
; CHECK-LABEL: define ptr @overwrite(
; CHECK: call ptr @malloc(i64 4){{.*}}, !alloc_token [[MD]]
define ptr @overwrite() {
  %c = call ptr @wrapper_own(i64 4), !alloc_token !0
  ret ptr %c
}

; Unless the call site's denotes an unknown type.
; CHECK-LABEL: define ptr @no_overwrite_unknown(
; CHECK: call ptr @malloc(i64 4){{.*}}, !alloc_token [[OWN:![0-9]+]]
define ptr @no_overwrite_unknown() {
  %c = call ptr @wrapper_own(i64 4), !alloc_token !4
  ret ptr %c
}

define internal ptr @wrapper_unknown(i64 %size) alwaysinline {
  %p = call ptr @malloc(i64 %size), !alloc_token !3
  ret ptr %p
}

; A wrapper's unknown type (empty type name) is overridden too.
; CHECK-LABEL: define ptr @overwrite_unknown(
; CHECK: call ptr @malloc(i64 4){{.*}}, !alloc_token [[CALLER:![0-9]+]]
define ptr @overwrite_unknown() {
  %c = call ptr @wrapper_unknown(i64 4), !alloc_token !2
  ret ptr %c
}

; CHECK-DAG: [[MD]] = !{!"Outer", i1 true}
; CHECK-DAG: [[OWN]] = !{!"Inner", i1 false}
; CHECK-DAG: [[CALLER]] = !{!"Outer", i1 true, !"overwrite_unknown"}
!0 = !{!"Outer", i1 true}
!1 = !{!"Inner", i1 false}
!2 = !{!"Outer", i1 true, !"overwrite_unknown"}
!3 = !{!"", i1 false, !"wrapper_unknown"}
!4 = !{!"", i1 false, !"no_overwrite_unknown"}
