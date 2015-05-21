## String Interpolation

This is a small string interpolation library for Nim providing a prinftf-like syntax.
The library was inspired by Scala's string interpolation and provides a similar interface.

Basically there are three formatting templates/macros:

- `ifmt*(formatString: string): expr`

  Internally, this is a wrapper for `format`. 
  The format string can contain indentifiers `ifmt"x = $x"` or expressions `ifmt"x = ${x+1}"`.
  Both can have a printf format suffix e.g. `ifmt"iteration = $i%5d, error = ${error*100}%6.2f %%"`.
  If there are no formatters, a `%s` formatter will be used, which will lead to a call to `$` (see `format`).
  In order to escape `$` or `%` in the format string, use `$$` and `%%`.
  A type mismatch or an ill-formated format string produces a compile-time error.

- `format*(formatString: string{lit}, args: varargs[expr]): expr`

  This is a wrapper for `formatUnsafe` and performs additional type checking of the arguments.
  There is a special rule for `%s`: 
  If the correponding argument is not a `string`, the macro will issue a call to `$` to convert it.
  If all arguments have proper type (or can be converted to string), a call to `formatUnsafe` is generated.
  Due to the compile-time type checking `formatString` must be a static string literal.

- `formatUnsafe*(formatString: string, args: varargs[expr]): string`
  
  This template provides a simple wrapper for `snprintf`. 
  No type checking is performed, allowing to use dynamic format strings.
  Internally, the template takes a two-step approach:
  In a first call to `snprintf` a fixed size (256) buffer is provided.
  If `snprintf` reports that the buffer was too small, a second call is performed with exactly the size required.
  As a result, there is no limitation on the maximum string size of the arguments.

### TODO: 

- The validation of printf formatters is still very basic. Lots of room for improvement.
- Much more testing is required, especially regarding various type checks.
