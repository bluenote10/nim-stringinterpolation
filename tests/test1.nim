import ../stringinterpolation

proc test*(format: string) =
  let s: string = ifmt"nothing to do"
  echo s
  echo format

test("test")

