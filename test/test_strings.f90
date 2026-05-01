program test_strings
  ! Test 5: Character/String operations
  character(len=20) :: str1, str2
  character(len=40) :: str3

  print *, "=== Test 5: Characters ==="
  str1 = "Hello"
  str2 = "World"
  str3 = trim(str1) // " " // str2
  print *, "Concatenated: '", trim(str3), "'"
  print *, "len(str3) =", len(str3)
  print *, "len_trim(str3) =", len_trim(str3)
  print *, "index('Hello World', 'World') =", index("Hello World", "World")
  print *, "Char(65) = ", char(65)
  print *, "Ichar('A') = ", ichar('A')
  print *, "Strings: ok"
end program test_strings
