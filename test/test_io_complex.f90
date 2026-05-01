program test_io_complex
  ! Test 9: Complex I/O
  integer :: ios, i
  character(len=80) :: line

  print *, "=== Test 9: Complex I/O ==="

  write(line, *) "internal write test"
  print *, "Internal: ", trim(line)

  write(*, '(A)', advance='no') "Counting:"
  do i = 1, 5
    write(*, '(I3)', advance='no') i
  end do
  write(*,*)
  print *, "Complex I/O: ok"
end program test_io_complex
