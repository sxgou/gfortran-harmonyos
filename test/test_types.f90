program test_types
  use iso_c_binding
  ! Test 6: Derived types and iso_c_binding
  type :: point
    real :: x, y
    character(len=10) :: label
  end type point
  type(point) :: p

  print *, "=== Test 6: Derived Types ==="
  p%x = 1.5
  p%y = 2.5
  p%label = "origin"
  print *, "Point (", p%x, ",", p%y, "): ", trim(p%label)

  print *, "C types:"
  print *, "  C_INT =", c_int
  print *, "  C_DOUBLE =", c_double
  print *, "  C_FLOAT =", c_float
  print *, "Types: ok"
end program test_types
