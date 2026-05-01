program test_random
  ! Test 8: Random numbers
  real :: r(5)
  integer :: seed_size
  integer, allocatable :: seed(:)

  print *, "=== Test 8: Random Numbers ==="

  call random_seed(size=seed_size)
  print *, "Seed size =", seed_size

  allocate(seed(seed_size))
  seed = 12345
  call random_seed(put=seed)

  call random_number(r)
  print *, "Random(5):", r
  print *, "Random: ok"
end program test_random
