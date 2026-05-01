program test_format
  ! Test 7: Format statements
  integer :: i
  real :: x

  x = 3.14159
  print *, "=== Test 7: Format ==="

  write(*,10) "Hello", 42, x
10 format(A, " | int=", I0, " | real=", F8.4)

  write(*,20) "Pad", 7
20 format(A10, " int=", I5.3)

  write(*,30) (i, i=1,5)
30 format("1..5: ", 5I3)

  print *, "Format: ok"
end program test_format
