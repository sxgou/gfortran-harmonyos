program test_fileio
  ! Test 3: File I/O
  character(len=50) :: msg
  integer :: ios

  print *, "=== Test 3: File I/O ==="
  open(unit=10, file="/data/storage/el2/base/fortran_test.txt", &
       status="replace", action="write", iostat=ios)
  if (ios /= 0) then
    print *, "FAIL: open for write, iostat=", ios
    stop 1
  end if
  write(10,*) "Hello from Fortran file I/O"
  write(10,*) "Line 2: pi =", 3.14159
  close(10)
  print *, "Write: ok"

  open(unit=11, file="/data/storage/el2/base/fortran_test.txt", &
       status="old", action="read", iostat=ios)
  if (ios /= 0) then
    print *, "FAIL: open for read, iostat=", ios
    stop 1
  end if
  read(11,*) msg
  print *, "Read back: '", trim(msg), "'"
  close(11)
  print *, "File I/O: ok"
end program test_fileio
