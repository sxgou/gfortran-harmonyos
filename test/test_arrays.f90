program test_arrays
  ! Test 4: Arrays
  integer, dimension(5) :: a
  integer :: i
  real, dimension(3,3) :: mat
  integer, dimension(3) :: b

  a = [1, 2, 3, 4, 5]
  print *, "=== Test 4: Arrays ==="
  print *, "Array a:", a
  print *, "a(3) =", a(3), "(expect 3)"
  print *, "Sum =", sum(a), "(expect 15)"
  print *, "Minval =", minval(a), "(expect 1)"
  print *, "Maxval =", maxval(a), "(expect 5)"

  b = a(1:3)
  print *, "Slice a(1:3):", b

  mat = reshape([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0], [3,3])
  print *, "Matrix(2,2) =", mat(2,2), "(expect 5.0)"
  print *, "Arrays: ok"
end program test_arrays
