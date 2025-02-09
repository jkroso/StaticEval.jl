# StaticEval.jl

Evaluates Julia expressions just like normal eval except when it hits an undefined variable it doesn't error, it just returns the expression with the static bits evaluated. Useful mainly to optimise the final expression you return from a macro.

```julia
@use "github.com/jkroso/StaticEval.jl" static_eval

a = 2
static_eval(:(1 + a), @__MODULE__) == 3
static_eval(:(true ? 1 : 2)) == 1
static_eval(:(false ? 1 : a+b), @__MODULE__) == :($+(2,b))
```
