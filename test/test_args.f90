program test_args
  ! Test: Command line arguments
  character(len=80) :: arg
  integer :: i, n

  print *, "=== Command Line Arguments ==="
  n = command_argument_count()
  print *, "Number of arguments:", n

  call get_command_argument(0, arg)
  print *, "Program name: ", trim(arg)

  do i = 1, n
    call get_command_argument(i, arg)
    print *, "Arg", i, ": ", trim(arg)
  end do
  print *, "Args: ok"
end program test_args
