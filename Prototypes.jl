

# ————————————————————————————————————————————
# ——————————— 2. Objects and Slots ———————————
# ————————————————————————————————————————————

mutable struct Object 
    slots::Dict{Symbol, Any}
    parents::Vector{Object}
end

const lobby = Object(Dict{Symbol, Any}(), Vector{Object}())


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

    error("Slot $(name) not found in object or its parents")
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
    else
        id = objectid(obj)
        slots = own_slots(obj)

        print("<Object $id ")
        for (i, k) in enumerate(slots)
            val = get_slot(obj, k)
            print("$k=$val")
            if i < length(slots)
                print(", ")
            end
        end
        print(">")
    end
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

#=


# ————————————————————————————————————————————
# ———————————— 4. Message Passing ————————————
# ————————————————————————————————————————————

send(obj, msg, args...) 


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