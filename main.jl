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
is_static(x::QuoteNode) = true
is_static(ex::Expr) = begin
  (Meta.isexpr(ex, :kw, 2) || Meta.isexpr(ex, :(=), 2)) && return is_static(ex.args[2])
  all(is_static, ex.args)
end

static_eval(x, ctx::Context) = x
static_eval(s::Symbol, ctx::Context) = begin
  result = lookup(ctx, s)
  result == undefined ? s : result
end
static_eval(ex::Expr, ctx::Context) = static_eval(ex, Val(ex.head), ctx)

eval_args(ex, ctx) = map(a->static_eval(a, ctx), ex.args)

"QuoteNodes are static but need to be left intact in the case that the Expr that contains them remains an Expr"
eval_quotenodes(ex) = ex
eval_quotenodes(q::QuoteNode) = q.value
eval_quotenodes(exs::Vector) = map(eval_quotenodes, exs)

static_eval(ex, ::Val{:call}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) || return Expr(:call, args...)
  Meta.eval(Expr(:call, args...))
end

static_eval(ex, ::Val{:kw}, ctx) = begin
  Expr(:kw, ex.args[1], static_eval(ex.args[2], ctx))
end

static_eval(ex, ::Val{:parameters}, ctx) = begin
  Expr(:parameters, eval_args(ex, ctx)...)
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
  all(is_static, args) || length(args) == 1 ? args[end] : Expr(:block, args...)
end

static_eval(ex, ::Val{:let}, ctx) = begin
  args = eval_args(ex, Context(ctx))
  all(is_static, args) && return args[end]
  Expr(:let, args...)
end

static_eval(ex, ::Val{:(=)}, ctx) = begin
  var, val = ex.args
  val = static_eval(val, ctx)
  ctx.dict[var] = val
  Expr(:(=), var, val)
end

static_eval(ex, ::Val{:vect}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) || return Expr(:vect, args...)
  eval_quotenodes(args)
end

static_eval(ex, ::Val{:tuple}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) || return Expr(:tuple, args...)
  tuple(eval_quotenodes(args)...)
end

static_eval(ex, ::Val{:curly}, ctx) = begin
  args = eval_args(ex, ctx)
  all(is_static, args) || return Expr(:curly, args...)
  Meta.eval(Expr(:curly, args...))
end

static_eval(ex, ::Val{:escape}, ctx) = begin
  @assert Meta.isexpr(ex, :escape, 1)
  arg = static_eval(ex.args[1])
  is_static(arg) ? arg : esc(arg)
end

static_eval(expr, mod=@__MODULE__) = static_eval(expr, Context(mod))

macro static_eval(ex)
  ex = static_eval(ex, __module__)
  ex isa Expr ? esc(ex) : ex
end
