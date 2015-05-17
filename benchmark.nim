import strfmt
import strutils
import stringinterpolation as si
import times

template runTimed*(benchmark: string, code: stmt): stmt {.immediate.} =
  block:
    let s = cpuTime()
    let s2 = epochTime()
    block:
      code
    let e = cpuTime()
    let e2 = epochTime()
    echo "\nBenchmark: ", benchmark
    #echo interp"  Epoch: ${e2-s2}%8.6f sec"
    #echo interp"  CPU:   ${e-s}%8.6f sec"
    #echo ifmt"  Epoch: ${e2-s2}%8.6f sec"
    #echo ifmt"  CPU:   ${e-s}%8.6f sec"
    echo format("  Epoch: %.3f sec", e2-s2)
    echo format("  CPU:   %.3f sec", e-s)

    # TODO: find out why this works:
    #echo si.format("%f", e2)
    # but not this
    #echo ifmt"$e2"


let 
  i = 1
  x = 1.0
  s = "hello world"

let s1 = ifmt"i = $i%5d    x = $x%5.2f    s = | $s%-20s |"
let s2 = interp"i = ${i:5d}    x = ${x:5.2f}    s = | ${s:<20s} |"
let s3 = "i = $1    x = $2    s = | $3 |" % [align($i, 5), x.formatFloat(ffDecimal,2).align(5), s.align(20)]

echo s1
echo s2
echo s3

const
  iterations = 1000000

runTimed("ifmt"):
  var arr = newSeq[string]()
  for iter in 1 .. iterations:
    let s = ifmt"i = $i%5d    x = $x%5.2f    s = | $s%-20s |"
    arr.add(s)

runTimed("interp"):
  var arr = newSeq[string]()
  for iter in 1 .. iterations:
    let s = interp"i = ${i:5d}    x = ${x:5.2f}    s = | ${s:<20s} |"
    arr.add(s)

runTimed("strutils"):
  var arr = newSeq[string]()
  for iter in 1 .. iterations:
    let s = "i = $1    x = $2    s = | $3 |" % [align($i, 5), x.formatFloat(ffDecimal,2).align(5), s.align(20)]
    arr.add(s)
