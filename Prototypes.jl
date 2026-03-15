

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
    # TODO
end

function own_slots(obj::Object)
    collect(keys(getfield(obj, :slots)))
end

function get_slot(obj::Object, name::Symbol)
    getfield(obj, :slots)[name]
end

#= FALTA 
    julia> point.z
    3

    julia> point.x = 10
    10
=#

#=

# ————————————————————————————————————————————
# ————————— 3. Cloning and Delegation ————————
# ————————————————————————————————————————————

clone(proto; slots...) 


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