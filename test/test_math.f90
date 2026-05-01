program test_math
  ! Test 2: Math intrinsics
  print *, "=== Test 2: Math Intrinsics ==="
  print *, "sin(0.0) =", sin(0.0d0), "(expect 0.0)"
  print *, "cos(0.0) =", cos(0.0d0), "(expect 1.0)"
  print *, "sqrt(4.0) =", sqrt(4.0d0), "(expect 2.0)"
  print *, "exp(1.0) =", exp(1.0d0), "(expect ~2.718)"
  print *, "log(2.71828) =", log(2.71828d0), "(expect ~1.0)"
  print *, "atan(1.0) =", atan(1.0d0), "(expect ~0.785)"
  print *, "abs(-3) =", abs(-3), "(expect 3)"
  print *, "mod(10,3) =", mod(10, 3), "(expect 1)"
  print *, "max(3,7,5) =", max(3, 7, 5), "(expect 7)"
  print *, "min(3,7,5) =", min(3, 7, 5), "(expect 3)"
  print *, "floor(3.7) =", floor(3.7d0), "(expect 3)"
  print *, "ceiling(3.2) =", ceiling(3.2d0), "(expect 4)"
  print *, "nint(3.7) =", nint(3.7d0), "(expect 4)"
  print *, "aint(3.7) =", aint(3.7d0), "(expect 3.0)"
end program test_math
