program test_basic
  ! Test 1: Basic I/O
  print *, "=== Test 1: Basic I/O ==="
  print *, "Hello, HarmonyOS Fortran!"
  print *, "Integer:", 42
  print *, "Real:", 3.14159
  print *, "Double:", 3.14159265358979d0
  print *, "Complex:", (1.0, 2.0)
  print *, "Logical:", .true.
  print *, "String: ", "test passed"
  write(*,*) "Write to stdout: ok"
end program test_basic
