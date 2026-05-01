program test_where
  ! Test 13: Where/Forall/Elemental
  real :: a(5), b(5)
  integer :: i, mask(5)

  print *, "=== Test 13: Where/Forall ==="
  a = [1.0, -2.0, 3.0, -4.0, 5.0]
  where (a > 0)
    b = sqrt(a)
  elsewhere
    b = 0.0
  end where
  print *, "Where test:", b, "(expect 1,0,~1.73,0,~2.24)"

  ! Pack/Unpack
  mask = [1, 0, 1, 0, 1]
  print *, "Packed:", pack(a, mask > 0), "(expect 1,3,5)"

  ! Merge
  print *, "Merge:", merge(a, -a, a > 0), "(expect 1,2,3,4,5)"
  print *, "Where: ok"
end program test_where
