# ————————————————————————————————————————————
# ——————————— 2. Objects and Slots ———————————
# ————————————————————————————————————————————

mutable struct Object
    slots::Dict{Symbol,Any}
    parents::Vector{Object}
end

const lobby = Object(Dict{Symbol,Any}(
        :doesNotUnderstand => (self, msg) -> println("ERROR: Object does not understand message ", repr(msg)),
        :clone => (self) -> clone(self),
        :isA => (self, proto) -> begin
            if self === proto
                return true
            end

            for parent in get_parents(self)
                if send(parent, :isA, proto)
                    return true
                end
            end
            return false
        end,
        :respondsTo => (self, slot) -> has_slot(self, slot)
    ), Vector{Object}())


function object(; slots...)
    d = Dict{Symbol,Any}()

    for (k, v) in slots
        d[k] = v
    end

    Object(d, Object[lobby])
end

function get_parents(obj::Object)
    getfield(obj, :parents)
end

function set_slot!(obj::Object, name::Symbol, val::Any)
    getfield(obj, :slots)[name] = val
    val
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

function own_slots(obj::Object)
    sort(collect(keys(getfield(obj, :slots))))
end

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

# —————————— Custom property get method ——————————

function Base.getproperty(obj::Object, name::Symbol)
    if name === :slots || name === :parents
        return getfield(obj, name)
    end

    get_slot(obj, name)
end

# ———————————— Custom property set method ————————————

function Base.setproperty!(obj::Object, name::Symbol, val)
    if name === :slots || name === :parents
        return setfield!(obj, name, val)
    end

    set_slot!(obj, name, val)
end

# ———————————— Custom object show method ————————————

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
# ————————— 3. Cloning and Delegation ————————
# ————————————————————————————————————————————

function clone(proto; slots...)
    d = Dict{Symbol,Any}()

    for (k, v) in slots
        d[k] = v
    end

    Object(d, Object[proto])
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

function set_parents!(obj, parents...)
    setfield!(obj, :parents, collect(parents))
end

# ————————————————————————————————————————————
# ———————————— 4. Message Passing ————————————
# ————————————————————————————————————————————

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

# ————————————————————————————————————————————
# ———— 7. Control Structures as Messages —————
# ————————————————————————————————————————————

true_obj = object(;
    Dict{Symbol,Any}(
        :ifTrue => (self, block) -> block(),
        :ifFalse => (self, block) -> nothing,
        :ifTrueIfFalse => (self, trueBlock, falseBlock) -> trueBlock(),
        :not => (self) -> false_obj,
        :and => (self, block) -> block,
        :or => (self, block) -> self
    )...
)

false_obj = object(;
    Dict{Symbol,Any}(
        :ifTrue => (self, block) -> nothing,
        :ifFalse => (self, block) -> block(),
        :ifTrueIfFalse => (self, trueBlock, falseBlock) -> falseBlock(),
        :not => (self) -> true_obj,
        :and => (self, block) -> self,
        :or => (self, block) -> block
    )...
)

function bool_object(b::Bool)
    return b ? true_obj : false_obj
end

function block_object(f::Function)
    return object(;
        Dict{Symbol,Any}(
            :value => (self, args...) -> f(args...),
            :whileTrue => (self, block) -> begin
                cond = send(self, :value)
                send(cond, :ifTrueIfFalse, () -> begin
                        send(block, :value)
                        send(self, :whileTrue, block)
                    end, () -> nothing)
            end,
            :whileFalse => (self, block) -> begin
                cond = send(self, :value)
                send(cond, :ifTrueIfFalse, () -> nothing, () -> begin
                    send(block, :value)
                    send(self, :whileFalse, block)
                end)
            end
        )...
    )
end

function range_object(r::AbstractRange)
    return object(;
        Dict{Symbol,Any}(
            :do => (self, block) -> begin
                start = first(r)
                s = step(r)
                stop = last(r)

                cond = send((x, y) -> (x <= y), :value, start, stop)
                send(cond, :ifTrueIfFalse, () -> begin
                        send(block, :value, start)
                        send((start+s):s:stop, :do, block)
                    end, () -> nothing)
            end,
            :collect => (self) -> begin
                result = []
                send(self, :do, (i) -> begin
                    push!(result, i)
                end)
                result
            end,
            :select => (self, block) -> begin
                selected = []
                send(self, :do, (i) -> begin
                    cond = send(block, :value, i)
                    send(cond, :ifTrueIfFalse, () -> push!(selected, i), () -> nothing)
                end)
                selected
            end,
            :injectInto => (self, value, op) -> begin
                acc = value
                send(self, :do, (i) -> begin
                    acc = op(acc, i)
                end)
                acc
            end,
            :by => (self, step) -> range_object(first(r):step:last(r))
        )...
    )
end

function number_object(n::Number)
    return object(;
        Dict{Symbol,Any}(
            :to => (self, range) -> range_object(n:range),
            :do => (self, block) -> send(send(0, :to, n - 1), :do, block),
            :timesRepeat => (self, block) -> begin
                cond = send((x) -> (x > 0), :value, n)
                send(cond, :ifTrueIfFalse, () -> begin
                        send(block, :value)
                        send(n - 1, :timesRepeat, block)
                    end, () -> nothing)
            end
        )...
    )
end

function to_object(x)
    if x isa Object
        return x
    elseif x isa Bool
        return bool_object(x)
    elseif x isa Function
        return block_object(x)
    elseif x isa AbstractRange
        return range_object(x)
    elseif x isa Number
        return number_object(x)
    end
end

# ————————————————————————————————————————————
# ———————————————— 8. Become —————————————————
# ————————————————————————————————————————————

function become!(a, b)
    a === b && return nothing

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

#=

# ————————————————————————————————————————————
# ———————————————— 9. Traits —————————————————
# ————————————————————————————————————————————

function trait(; methods...)
    
end

function compose_traits(traits...; resolve)
    
end

function use_trait!(obj, trait)
    
end

# ————————————————————————————————————————————
# ——————— 12. Smalltalk-Style Syntax —————————
# ————————————————————————————————————————————

macro send(expr...)

end

=#