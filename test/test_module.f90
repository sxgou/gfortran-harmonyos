module math_utils
  implicit none
contains
  function factorial(n) result(f)
    integer, intent(in) :: n
    integer :: f, i
    f = 1
    do i = 2, n
      f = f * i
    end do
  end function factorial

  function fibonacci(n) result(f)
    integer, intent(in) :: n
    integer :: f, a, b, i
    if (n <= 1) then
      f = n
    else
      a = 0; b = 1
      do i = 2, n
        f = a + b
        a = b; b = f
      end do
    end if
  end function fibonacci
end module math_utils

program test_module
  use math_utils
  print *, "=== Test 12: Modules ==="
  print *, "factorial(5) =", factorial(5), "(expect 120)"
  print *, "factorial(10) =", factorial(10), "(expect 3628800)"
  print *, "fibonacci(10) =", fibonacci(10), "(expect 55)"
  print *, "Modules: ok"
end program test_module
