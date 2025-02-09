struct Context
  mod::Module
  dict::Dict{Symbol,Any}
  parent::Union{Nothing,Context}
end

Context(mod::Module) = Context(mod, Dict{Symbol,Any}(), nothing)
Context(ctx::Context) = Context(ctx.mod, Dict{Symbol,Any}(), ctx)

const undefined = gensym("undefined")

lookup(ctx::Context, k::Symbol) = begin
  haskey(ctx.dict, k) && return ctx.dict[k]
  isdefined(ctx.mod, k) && return getfield(ctx.mod, k)
  isnothing(ctx.parent) && return undefined
  lookup(ctx.parent, k)
end

is_static(x) = true
is_static(x::Symbol) = false
is_static(ex::Expr) = all(is_static, ex.args)

static_eval(x, ctx::Context) = x
static_eval(s::Symbol, ctx::Context) = begin
  result = lookup(ctx, s)
  result == undefined ? s : result
end
static_eval(ex::Expr, ctx::Context) = static_eval(ex, Val(ex.head), ctx)

eval_args(ex, ctx) = map(a->static_eval(a, ctx), ex.args)

static_eval(ex, ::Val{:call}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) && return args[1](args[2:end]...)
  Expr(:call, args...)
end

static_eval(ex, ::Val{:if}, ctx) = begin
  args = eval_args(ex, ctx)
  if is_static(args[1])
    args[1] ? args[2] : length(args) > 2 ? args[3] : nothing
  else
    Expr(:if, args...)
  end
end

rmlines(exprs) = [x for x in exprs if !(x isa LineNumberNode)]

static_eval(ex, ::Val{:block}, ctx) = begin
  args = rmlines(eval_args(ex, ctx))
  all(is_static, args) || length(args) == 1 && return args[end]
  Expr(:block, args...)
end

static_eval(ex, ::Val{:let}, ctx) = begin
  args = eval_args(ex, Context(ctx))
  all(is_static, args) && return args[end]
  Expr(:let, args...)
end

static_eval(ex, ::Val{:(=)}, ctx) = begin
  var, val = ex.args
  ctx.dict[var] = static_eval(val, ctx)
end

static_eval(ex, ::Val{:vect}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) && return args
  Expr(:vect, args...)
end

static_eval(ex, ::Val{:tuple}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) && return tuple(args...)
  Expr(:tuple, args...)
end

static_eval(expr, mod=@__MODULE__) = static_eval(expr, Context(mod))

macro static_eval(ex)
  ex = static_eval(ex, __module__)
  ex isa Expr ? esc(ex) : ex
end
