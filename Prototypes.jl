

# ————————————————————————————————————————————
# ——————————— 2. Objects and Slots ———————————
# ————————————————————————————————————————————

mutable struct Object 
    slots::Dict{Symbol, Any}
    parents::Vector{Object}
end

const lobby = Object(Dict{Symbol, Any}(
    :doesNotUnderstand => (self, msg) -> begin
        println("ERROR: Object does not understand message ", repr(msg))
    end
    ), Vector{Object}())


function object(; slots...) 
    d = Dict{Symbol, Any}()

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
    d = Dict{Symbol, Any}()

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
    func = get_slot(obj, msg)
    if func === nothing || msg === :doesNotUnderstand
        does_not_understand = get_slot(obj, :doesNotUnderstand)
        return does_not_understand(obj, msg)
    elseif func isa Function
        return func(obj, args...)
    end
    return func
end

#=

# ————————————————————————————————————————————
# —————————— 5. Does Not Understand ——————————
# ————————————————————————————————————————————

get_slot(obj, name), set_slot!(obj, name, value)


# ————————————————————————————————————————————
# ———————————— 6. Lobby Defaults —————————————
# ————————————————————————————————————————————

has_slot(obj, name), has_own_slot(obj, name)

# ————————————————————————————————————————————
# ———— 7. Control Structures as Messages —————
# ————————————————————————————————————————————

own_slots(obj) 

# ————————————————————————————————————————————
# ———————————————— 8. Become —————————————————
# ————————————————————————————————————————————

get_parents(obj), add_parent!(obj, parent), remove_parent!(obj, parent),

# ————————————————————————————————————————————
# ———————————————— 9. Traits —————————————————
# ————————————————————————————————————————————

set_parents!(obj, parents...) 

# ————————————————————————————————————————————
# —————— 10. Dynamic Object Evolution ————————
# ————————————————————————————————————————————

become!(a, b)


trait(; methods...), compose_traits(traits...; resolve),


use_trait!(obj, trait)


to_object(x)

=#