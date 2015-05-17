
import macros
import typetraits
import nre
import optional_t
import sets


macro appendVarargs(c: expr, e: expr): expr =
  #echo c.treerepr
  result = c
  for a in e.children:
    result.add(a)
  #echo result.treerepr

proc snprintf(buffer: ptr cchar, n: csize, formatstr: cstring): cint
  {.importc: "snprintf", varargs, header: "<stdio.h>".}

template formatUnsafe*(formatString: string, args: varargs[expr]): string =
  ## performs a string formatting _without_ type checking. On the other hand,
  ## this allows to pass a formatString which is not a static literal.
  ## This means that it is possible to use dynamic string format strings, e.g.
  ## formatUnsafe("%" & $dynamicNumberOfDigits & "d", 1_000_000)
  
  # determine the required size first
  let requiredSize = appendVarargs(snprintf(nil, 0, formatString), args)
  # note: method call syntax passes a different tree!

  if requiredSize < 0:
    raise newException(ValueError, "illegal format string \"" & formatString & "\"")

  # now create string of appropriate size
  var s = newStringOfCap(requiredSize + 1) # +1 because requiredSize does not include '\0'

  # call snprintf again (we can discard the size this time)
  discard appendVarargs(snprintf(cast[ptr cchar](s.cstring), requiredSize+1, formatString), args)
  s.setlen(requiredSize)
  s


# TODO: make some unittests
when false:
  let s = formatUnsafe("%3d %8.3fX", 42+1, 3.14)
  echo formatUnsafe("%3d %12.3fX", 42, 3.14)
  echo s.len
  echo s

  var digits = 15
  echo formatUnsafe("%" & $digits & "d", 1_000_000)

  echo formatUnsafe("Hallo 1%% Test")




type
  FormatStringMatchEnum = enum
    fsInvalid, fsPct, fsMatch

  FormatStringMatch = object
    case kind: FormatStringMatchEnum
    of fsMatch:
      s: string
    else:
      discard

proc len(m: FormatStringMatch): int =
  case m.kind:
  of fsInvalid: 0
  of fsPct: 1
  of fsMatch: m.s.len

proc typeSpecifier(m: FormatStringMatch): char =
  if m.kind == fsMatch:
    m.s[^1]
  else:
    '\0'

proc parseFormatString(s: string): FormatStringMatch =
  if s[0] == '%':
    return FormatStringMatch(kind: fsPct)

  let flags     = r"(-|\+| |0|#)*" # r"-?\+? ?0?#?" this is order dep, but the new allows multiples...
  let width     = r"\d*"
  let precision = r"(\.\d+)?" # optional, if given min 1 digit
  let length    = r"(h|hh|l|ll|L|j|z|t)?"
  let specifier = r"[diufFeEgGxXoscppaAn]"

  let regexp = re(flags & width & precision & length & specifier)
  let mo = s.match(regexp)
  if mo.isSome:
    let m = mo.get
    return FormatStringMatch(kind: fsMatch, s: m.match)

  return FormatStringMatch(kind: fsInvalid)


proc parseFormatStringStupid(s: string): FormatStringMatch =
  ## non-re version
  if s[0] == '%':
    return FormatStringMatch(kind: fsPct)

  let terminating = {'d', 'i', 'u', 'f', 'F', 'e', 'E', 'g', 'G', 'x', 'X', 'o', 's', 'c', 'p', 'p', 'a', 'A', 'n'}

  for i, c in s:
    if c in terminating:
      return FormatStringMatch(kind: fsMatch, s: s[0..i])

  return FormatStringMatch(kind: fsInvalid)

when false:
  let strings = [
    "%asdf",
    "ddd",
    " d",
    " +-0#d",
    "f",
    "d",
    "s",
    "5f",
    "5.1f",
    ".2f",
    "50.20f",
    "5.2.2f",
    "5.f",
    "zu",
    "zzu",
    "hhd",
    "hhhhd",
  ]
  for s in strings:
    let m = parseFormatString(s)
    let m2 = parseFormatStringStupid(s)
    echo "Expression: '", s, "' => ", m, " match len: ", m.len, "   ", m2
    #assert m.kind == m2.kind
    #assert m.len == m2.len


proc extractFormatStrings(s: string): seq[FormatStringMatch] =

  result = newSeq[FormatStringMatch]()
  var i = 0

  while i < s.len:
    let c = s[i]
    echo s, i, c, result
    if c == '%':
      let m = parseFormatStringStupid(s[i+1..^1]) 
      if m.kind == fsMatch:
        result.add(m)
      i += m.len
    inc i

#echo extractFormatStrings("%s %s %.3d")


macro format*(formatString: string{lit}, args: varargs[expr]): expr =
  ## formats a static format string, with arguments of variable type.
  ## This is a typesafe version of ``formatUnsafe``. Internally, it performs
  ## type checking and generates a call to ``formatUnsafe``.

  echo formatString.strval
  let formatStrings = extractFormatStrings(formatString.strval)
  echo formatStrings
  echo formatStrings.len, " == ", args.len 
  if formatStrings.len != args.len:
    error "number of varargs ("  & $args.len & ") does not match number of string formatters (" & $formatStrings.len & ")"

  result = newCall("formatUnsafe", formatString)

  var i = 0
  for fs in formatStrings:
    echo i
    echo args[i].treerepr
    let actualType = args[i].getType
    let atk = actualType.typeKind
    echo "Actual Type: ", actualType.treerepr
    echo "Actual Type Kind: ", atk

    let typeSpecifier = fs.typeSpecifier
    echo "Type specifier: ", typeSpecifier

    type TypeMatchEnum = enum tmMatch, tmConvertToString, tmNoMatch

    proc checkIn(s: set[NimTypeKind]): TypeMatchEnum =
      if atk in s:
        tmMatch
      else:
        tmNoMatch

    let typeMatch = case typeSpecifier
      of 'c':
        checkIn({ntyChar})
      of 'd', 'i', 'x', 'X':
        # TODO: is this okay, we could type check if formatter has unsigned flag...
        checkIn({ntyInt, ntyInt8, ntyInt16, ntyInt32, ntyInt64, ntyUInt, ntyUInt8, ntyUInt16, ntyUInt32, ntyUInt64})
      of 'f', 'e', 'E', 'g', 'G':
        checkIn({ntyFloat, ntyFloat32, ntyFloat64, ntyFloat128})
      of 'p':
        # TODO: is this okay
        checkIn({ntyPtr, ntyRef}) 
      of 's':
        if atk == ntyString:
          tmMatch
        else:
          tmConvertToString
      else:
        tmNoMatch

    if typeMatch == tmNoMatch:
      error "string formatter '" & typeSpecifier & "' does not match type " & $atk # $symbol(actualType)
    elif typeMatch == tmConvertToString:
      add(result, prefix(args[i], "$"))
    else:
      add(result, args[i])

    inc i

  echo " *** Generated call: ", result.treerepr


when false:
  #let s = format("%3d %8.3fX", (42+1), 3.14*1.0)
  #let s = format("%3d %8.3fX %s", (42+1), 3.14*1.0, @[1,2,3])
  let s = format("%12d %s %s %5.3e", 42.int16, 3.14*1.0, @[1,2,3], 1.234)
  echo s.len
  echo s




const
  Whitespace = {' ', '\t', '\v', '\r', '\l', '\f'}
  IdentChars = {'a'..'z', 'A'..'Z', '0'..'9', '_'}
  IdentStartChars = {'a'..'z', 'A'..'Z', '_'}
   ## copied from parseutils, which copied from strutils
   ## maybe these characters should be exported in a single place?





proc isValidExpr(s: string): bool {.compileTime.} =
  try:
    discard parseExpr(s)
    return true
  except ValueError:
    return false



macro ifmt(formatStringNode: string): expr =

  let formatString = formatStringNode.strVal

  type
    ParseState = enum
      psNeutral, psOneDollar, psIdent, psExpr

  var state = psNeutral
  var buffer = ""
  var i = 0

  var outFmtStr = ""
  var outArgs = newSeq[NimNode]()

  while i < formatString.len:
    let c = formatString[i]
    echo c, " state: ", state
    case state

    of psNeutral:
      if c == '$':
        state = psOneDollar
        buffer.setlen(0) # clear buffer for ident/expr accumulation
        inc i
      elif c == '%':
        inc i
        if i < formatString.len and formatString[i] == '%':
          outFmtStr.add("%%")
          inc i
        else:
          error "format string contains an unescaped '%' character (use \"%%\" to escape)"
      else:
        outFmtStr.add(c)
        inc i

    of psOneDollar:
      if c == '$': # second dollar -> yield "$", return to neutral
        outFmtStr.add("$")
        state = psNeutral
      elif c == '{':
        state = psExpr
      elif c in IdentStartChars:
        state = psIdent
        buffer.add(c)
      else:
        error "a '$' character must either be followed by '$', an identifier, or a {} expression"
      inc i

    of psIdent:
      if c in IdentChars:
        buffer.add(c)
        inc i
      elif c == '%':
        outArgs.add(newIdentNode(buffer))
        let substr = formatString[i+1..^1]
        echo "substr: ", substr
        let formatter = parseFormatStringStupid(substr)
        echo "formatter: ", formatter
        
        case formatter.kind:
        of fsMatch:  # if we have a valid format string: append it and inc by '%' + formatter.len
          outFmtStr.add('%' & formatter.s)
          i += 1 + formatter.len
        of fsPct: # if the '%' char was actually an escaped double '%': provide default formatter + insert '%%'
          outFmtStr.add("%s%%")
          i += 1 + formatter.len # == 2, but written consistently
        of fsInvalid:
          error "could not parse format string '" & substr & "'"
        state = psNeutral
      else:
        outArgs.add(newIdentNode(buffer))
        outFmtStr.add("%s")
        state = psNeutral
        # note: we no _not_ increase i here
        # in order to parse the same character
        # again in neutral state, allowing to
        # check for '$'.

    of psExpr:
      echo "current expr: ", buffer
      if c == '}' and buffer.isValidExpr:
        outArgs.add(parseExpr(buffer))
        state = psNeutral
        inc i
        # peek into next char to see if we have a format string
        if i < formatString.len:
          let c = formatString[i]
          if c == '%':
            let substr = formatString[i+1..^1]
            echo "substr: ", substr
            let formatter = parseFormatStringStupid(substr)
            echo "formatter: ", formatter

            case formatter.kind:
            of fsMatch:  # if we have a valid format string: append it and inc by '%' + formatter.len
              outFmtStr.add('%' & formatter.s)
              i += 1 + formatter.len
            of fsPct: # if the '%' char was actually an escaped double '%': provide default formatter + insert '%%'
              outFmtStr.add("%s%%")
              i += 1 + formatter.len # == 2, but written consistently
            of fsInvalid:
              error "could not parse format string '" & substr & "'"
          else:
            # no explicit formatter: insert the default formatter
            outFmtStr.add("%s")
        else:
          # at end of string we have to insert the default formatter
          outFmtStr.add("%s")
      else:
        buffer.add(c)
        inc i


  # handle termination
  if state == psIdent:
    outArgs.add(newIdentNode(buffer))
    outFmtStr.add("%s")
  elif state == psOneDollar or state == psExpr:
    error "format string is not properly terminated"


  echo " *** outFmtStr: ", outFmtStr
  echo " *** outArgs: ", outArgs.repr

  result = newCall("format", newStrLitNode(outFmtStr))

  for arg in outArgs:
    result.add(arg)

  echo result.treeRepr

block:
  let x = 1
  #echo ifmt" %% test x = $x%d$x%5s$x%%$x%%"

  #echo ifmt"%%${x+1}%5d${x+2}%s${3+x}%%$$$x$$"
  #echo formatUnsafe("%d%", x)
  #echo ifmt"% "
  #
  let s = "test"
  echo ifmt"""${s & "{}"}"""
