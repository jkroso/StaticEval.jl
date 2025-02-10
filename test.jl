@use "github.com/jkroso/Rutherford.jl/test.jl" @test
@use "./main.jl" @static_eval static_eval

a=2
@test 3 == @static_eval a+1
@test "ab" == @static_eval "a"*"b"
@test 1 == @static_eval if true 1 else 2 end
@test 1 == @static_eval if true 1 end
@test nothing == @static_eval if false 1 end
@test 3 == @static_eval let a=1;a+2 end
@test [1,2,3] == @static_eval [1,a,3]
@test (1,2) == @static_eval (1,2)
@test static_eval(:(if true d else e end)) == :d
@test static_eval(:(if false d else e end)) == :e
@test static_eval(:(if true d+1 else e end)) == :($+(d,1))
@test @macroexpand(@static_eval false ? 1 : a+b) == :($+(2,b))
@test @static_eval(Dict(:a => 1)) == Dict(:a => 1)
@test @static_eval(Dict{Symbol,Any}(:a => 1)) == Dict(:a => 1)

F(;r::Any) = r
F(r=1)
@test @static_eval(F(r=3)) == 3
@test @static_eval(F(;r=3)) == 3
