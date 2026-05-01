program test_allocs
  ! Test 10: Allocatable arrays
  integer, allocatable :: arr(:,:)
  integer :: n
  integer :: i, idx

  n = 100
  print *, "=== Test 10: Dynamic Memory ==="

  allocate(arr(n, n))
  idx = 0
  do i = 1, n
    arr(:, i) = [(idx + j, j=1,n)]
    idx = idx + n
  end do
  print *, "Allocated ", n, "x", n, " array"
  print *, "arr(1,1) =", arr(1,1), "(expect 1)"
  print *, "arr(1,2) =", arr(1,2), "(expect 101)"
  print *, "arr(2,1) =", arr(2,1), "(expect 2)"
  print *, "sum first col =", sum(arr(:,1)), "(expect 5050)"
  deallocate(arr)
  print *, "Dynamic memory: ok"
end program test_allocs
