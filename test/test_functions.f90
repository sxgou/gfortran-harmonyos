program test_functions
  ! Test 11: Functions and subroutines
  interface
    function add(a, b) result(c)
      integer, intent(in) :: a, b
      integer :: c
    end function add
  end interface
  integer :: x, y, z

  print *, "=== Test 11: Functions ==="
  x = 10
  y = 20
  z = add(x, y)
  print *, "add(", x, ",", y, ") =", z, "(expect 30)"

  call greet("Fortran")
  print *, "Functions: ok"
contains
  subroutine greet(name)
    character(len=*), intent(in) :: name
    print *, "Hello from ", trim(name)
  end subroutine greet
end program test_functions

function add(a, b) result(c)
  integer, intent(in) :: a, b
  integer :: c
  c = a + b
end function add
