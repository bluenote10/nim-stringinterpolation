import ../stringinterpolation

template test1*(code: stmt): stmt {.immediate.} =
  var x = 0
  echo format("%d", x)
  #echo ifmt"$x%d"
  code

template test2*(code: stmt): stmt =
  var x = 0
  echo format("%d", x)
  #echo ifmt"$x%d"
  code

template test3*(): stmt =
  var x = 0
  echo format("%d", x)
  #echo ifmt"$x%d"

template test4*(): expr =
  var x = 0
  echo format("%d", x)
  #echo ifmt"$x%d"
  "expr"


test1:
  echo "Hello World"
  echo ifmt"${1}"

test2:
  echo "Hello World"
  echo ifmt"${1}"

test3()

let x = test4()
