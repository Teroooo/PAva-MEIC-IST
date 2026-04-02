# ————————————————————————————————————————————
# ——————————————— Object Model ———————————————
# ————————————————————————————————————————————

mutable struct Object
    slots::Dict{Symbol,Any}
    parents::Vector{Object}
end

const lobby = Object(Dict{Symbol,Any}(), Vector{Object}())

function object(; slots...)
    d = Dict{Symbol,Any}(slots)
    Object(d, Object[lobby])
end

# —————————— Custom object methods ——————————

function Base.getproperty(obj::Object, name::Symbol)
    if name === :slots || name === :parents
        return getfield(obj, name)
    end

    get_slot(obj, name)
end

function Base.setproperty!(obj::Object, name::Symbol, val)
    if name === :slots || name === :parents
        return setfield!(obj, name, val)
    end

    set_slot!(obj, name, val)
end

function Base.show(io::IO, ::MIME"text/plain", obj::Object)
    if obj === lobby
        print("<lobby>")
        return
    elseif obj === true_obj
        print(true)
        return
    elseif obj === false_obj
        print(false)
        return
    end

    id = objectid(obj)
    slots = own_slots(obj)

    print("<Object $id ")

    first = true
    methods = []

    for k in slots
        val = get_slot(obj, k)
        # Skip functions
        if val isa Function
            push!(methods, k)
            continue
        end

        if !first
            print(", ")
        end

        if val isa Object
            print("$k=<Object $(objectid(val))>")
        elseif val isa String
            print("$k=\"$(val)\"")
        else
            print("$k=$val")
        end

        first = false
    end

    # Print methods separately
    if !isempty(methods)
        if !first
            print(", ")
        end
        print("methods=[", join(string.(methods), ", "), "]")
    end

    print(">")
end

# ————————————————————————————————————————————
# —————————————————— Slots ———————————————————
# ————————————————————————————————————————————

function get_slot(obj::Object, name::Symbol)
    if has_own_slot(obj, name)
        return getfield(obj, :slots)[name]
    end

    for parent in get_parents(obj)
        if has_slot(parent, name)
            return get_slot(parent, name)
        end
    end
    return nothing
end

function set_slot!(obj::Object, name::Symbol, val::Any)
    getfield(obj, :slots)[name] = val
    val
end

function own_slots(obj::Object)
    sort(collect(keys(getfield(obj, :slots))))
end

function has_own_slot(obj::Object, name::Symbol)
    name in keys(getfield(obj, :slots))
end

function has_slot(obj::Object, name::Symbol)
    if has_own_slot(obj, name)
        return true
    end

    for parent in get_parents(obj)
        if has_slot(parent, name)
            return true
        end
    end

    return false
end

# ————————————————————————————————————————————
# ———————————————— Delegation ————————————————
# ————————————————————————————————————————————

function set_parents!(obj, parents...)
    setfield!(obj, :parents, collect(parents))
end

function add_parent!(obj, parent)
    parents = getfield(obj, :parents)
    if parent in parents
        return parent
    end
    push!(parents, parent)
    return parent
end

function remove_parent!(obj, parent)
    parents = getfield(obj, :parents)
    idx = findfirst(isequal(parent), parents)

    if idx === nothing
        error("Parent not found in delegation chain")
    end

    deleteat!(parents, idx)
end

function get_parents(obj::Object)
    getfield(obj, :parents)
end

# ————————————————————————————————————————————
# ————————————— Object Semantics —————————————
# ————————————————————————————————————————————

function clone(proto; slots...)
    d = Dict{Symbol,Any}(slots)
    Object(d, Object[proto])
end

function become!(a, b)
    if a === b
        return nothing
    end

    a_slots = getfield(a, :slots)
    b_slots = getfield(b, :slots)
    setfield!(a, :slots, b_slots)
    setfield!(b, :slots, a_slots)

    a_parents = getfield(a, :parents)
    b_parents = getfield(b, :parents)
    setfield!(a, :parents, b_parents)
    setfield!(b, :parents, a_parents)

    return nothing
end

# ————————————————————————————————————————————
# —————————————— Message Passing —————————————
# ————————————————————————————————————————————

set_slot!(lobby, :doesNotUnderstand, (self, msg) -> println("ERROR: Object does not understand message ", repr(msg)))
set_slot!(lobby, :clone, (self) -> clone(self))
set_slot!(lobby, :isA, (self, proto) -> begin
    if self === proto
        return true
    end

    for parent in get_parents(self)
        if send(parent, :isA, proto)
            return true
        end
    end
    return false
end)
set_slot!(lobby, :respondsTo, (self, slot) -> has_slot(self, slot))

function send(obj, msg, args...)
    proto = to_object(obj)
    func = get_slot(proto, msg)
    if func === nothing || msg === :doesNotUnderstand
        does_not_understand = get_slot(proto, :doesNotUnderstand)
        return does_not_understand(proto, msg)
    elseif func isa Function
        return func(proto, args...)
    end
    return func
end

function to_object(o::Object)
    return o
end

function to_object(b::Bool)
    return b ? true_obj : false_obj
end

function to_object(f::Function)
    obj = object()

    set_slot!(obj, :value, (self, args...) -> f(args...))

    set_slot!(obj, :whileTrue, (self, block) -> begin
        cond = send(self, :value)
        send(cond, :ifTrueIfFalse,
            () -> begin
                send(block, :value)
                send(self, :whileTrue, block)
            end,
            () -> nothing)
    end)

    set_slot!(obj, :whileFalse, (self, block) -> begin
        cond = send(self, :value)
        send(cond, :ifTrueIfFalse,
            () -> nothing,
            () -> begin
                send(block, :value)
                send(self, :whileFalse, block)
            end)
    end)

    return obj
end

function to_object(r::AbstractRange)
    obj = object()

    set_slot!(obj, :do, (self, block) -> begin
        start = first(r)
        s = step(r)
        stop = last(r)

        cond = send((x, y) -> x <= y, :value, start, stop)

        send(cond, :ifTrueIfFalse,
            () -> begin
                send(block, :value, start)
                send((start+s):s:stop, :do, block)
            end,
            () -> nothing)
    end)

    set_slot!(obj, :collect, (self) -> begin
        result = []
        send(self, :do, (i) -> push!(result, i))
        result
    end)

    set_slot!(obj, :select, (self, block) -> begin
        selected = []
        send(self, :do, (i) -> begin
            cond = send(block, :value, i)
            send(cond, :ifTrueIfFalse,
                () -> push!(selected, i),
                () -> nothing)
        end)
        selected
    end)

    set_slot!(obj, :injectInto, (self, value, op) -> begin
        acc = value
        send(self, :do, (i) -> acc = op(acc, i))
        acc
    end)

    set_slot!(obj, :by, (self, s) ->
        to_object(first(r):s:last(r))
    )

    return obj
end

function to_object(n::Number)
    obj = object()

    set_slot!(obj, :to, (self, range) ->
        to_object(n:range)
    )

    set_slot!(obj, :do, (self, block) ->
        send(send(0, :to, n - 1), :do, block)
    )

    set_slot!(obj, :timesRepeat, (self, block) -> begin
        cond = send((x) -> x > 0, :value, n)

        send(cond, :ifTrueIfFalse,
            () -> begin
                send(block, :value)
                send(n - 1, :timesRepeat, block)
            end,
            () -> nothing)
    end)

    return obj
end

# ————————————————————————————————————————————
# ———————————— Control Structures ————————————
# ————————————————————————————————————————————

true_obj = object()
set_slot!(true_obj, :ifTrue, (self, block) -> send(block, :value))
set_slot!(true_obj, :ifFalse, (self, block) -> nothing)
set_slot!(true_obj, :ifTrueIfFalse, (self, trueBlock, falseBlock) -> send(trueBlock, :value))
set_slot!(true_obj, :not, (self) -> false_obj)
set_slot!(true_obj, :and, (self, block) -> block)
set_slot!(true_obj, :or, (self, block) -> self)

false_obj = object()
set_slot!(false_obj, :ifTrue, (self, block) -> nothing)
set_slot!(false_obj, :ifFalse, (self, block) -> send(block, :value))
set_slot!(false_obj, :ifTrueIfFalse, (self, trueBlock, falseBlock) -> send(falseBlock, :value))
set_slot!(false_obj, :not, (self) -> true_obj)
set_slot!(false_obj, :and, (self, block) -> self)
set_slot!(false_obj, :or, (self, block) -> block)

# ————————————————————————————————————————————
# —————————————————— Traits ——————————————————
# ————————————————————————————————————————————

function trait(; methods...)
    object(; methods...)
end

function compose_traits(traits...; resolve)
    dicts = map(trait -> getfield(trait, :slots), traits)
    dicts = merge(dicts...)
    for (k, v) in resolve
        dicts[k] = v
    end

    obj = object()
    setfield!(obj, :slots, dicts)
    obj
end

function compose_traits(traits...;)
    set = Dict{Symbol,Any}()
    for trait in traits
        for (k, v) in getfield(trait, :slots)
            if k ∉ keys(set)
                set[k] = v
            else
                println("ERROR: Trait conflict on: $k")
                return
            end
        end
    end
    println("No Trait conflicts")
end

function use_trait!(obj, trait)
    for (k, v) in getfield(trait, :slots)
        set_slot!(obj, k, v)
    end
end

# ————————————————————————————————————————————
# ——————————————— Send Macro —————————————————
# ————————————————————————————————————————————

# ── 1. Reconhecer bloco literal ───────────────────────────────────────────────
is_block_expr(ex) = ex isa Expr && ex.head in (:vect, :vcat)

function find_pipe_separator(ex)
    ex isa Expr || return nothing
    pipe = Symbol("|")

    if ex.head === :call && length(ex.args) == 3 && ex.args[1] === pipe
        return (ex.args[2], ex.args[3])
    end

    start = ex.head === :call ? 2 : 1
    for i in start:length(ex.args)
        result = find_pipe_separator(ex.args[i])
        if result !== nothing
            param, replacement = result
            new_args = copy(ex.args)
            new_args[i] = replacement          # substitui o nó | pelo seu rhs
            return (param, Expr(ex.head, new_args...))
        end
    end
    return nothing
end

function parse_block_expr(ex::Expr)
    if ex.head === :vcat
        return Expr(:->, Expr(:tuple), Expr(:block, ex.args...))
    end

    args = ex.args
    isempty(args) && return :((() -> nothing))

    result = find_pipe_separator(args[end])
    if result !== nothing
        last_param, body = result
        params = Any[args[1:end-1]..., last_param]
        lhs = length(params) == 1 ? params[1] : Expr(:tuple, params...)
        return Expr(:->, lhs, body)
    else
        body = length(args) == 1 ? args[1] : Expr(:block, args...)
        return Expr(:->, Expr(:tuple), body)
    end
end

camel_concat(kws::Vector{String}) =
    foldl((a, b) -> a * uppercasefirst(b), kws)

macro send(receiver, rest...)
    # O receiver pode ser ele próprio um bloco literal
    recv = is_block_expr(receiver) ? parse_block_expr(receiver) : receiver

    isempty(rest) && error("@send: falta a mensagem")
    first_tok = rest[1]

    if first_tok isa QuoteNode && first_tok.value isa Symbol
        # ── Mensagem keyword (uma ou mais) ──────────────────────────
        # Varre alternadamente: :keyword  arg arg ... :keyword  arg ...
        kws = String[]
        margs = []
        i = 1
        while i <= length(rest)
            tok = rest[i]
            tok isa QuoteNode && tok.value isa Symbol || break
            push!(kws, string(tok.value))
            i += 1
            while i <= length(rest) &&
                !(rest[i] isa QuoteNode && rest[i].value isa Symbol)
                arg = rest[i]
                push!(margs, is_block_expr(arg) ? parse_block_expr(arg) : arg)
                i += 1
            end
        end
        msg = QuoteNode(Symbol(camel_concat(kws)))
        return esc(:(send($recv, $msg, $(margs...))))

    elseif first_tok isa Symbol
        # ── Mensagem unária ─────────────────────────────────────────
        return esc(:(send($recv, $(QuoteNode(first_tok)))))

    else
        error("@send: esperado nome de mensagem (símbolo ou :keyword), recebi $first_tok")
    end
end