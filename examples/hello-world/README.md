# Hello World

The hello-world example is from https://nodejs.org/api/synopsis.html

While all the script is in the Julia language,
it can be very similar to JavaScript code, except for the following differences:

- `using NodeCall` is required, obviously.
- All string literals should be written within double quotation marks.
If string interpolation is needed, instead of `` `${x}` ``, `"$(x)"` should be used.
- Anonymous functions are defined as `(x) -> begin end` instead of `(x) => {}`.
