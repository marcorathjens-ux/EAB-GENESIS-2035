using DifferentialEquations, ZMQ, JSON, Base.Threads

# GLOBAL PARAMETERS (R4-01: Correct Atomic Initialization)
const p_alpha, p_b, p_k = 0.5, 0.1, 1.0
p_sigma = Threads.Atomic{Float64}(0.15) 

context = Context(); socket = Socket(context, PULL)
ZMQ.bind(socket, "tcp://*:5555")

# ASYNC RECEIVER (R4-02: Non-blocking with DONTWAIT)
@async while true
    try
        # DONTWAIT prevents freezing the entire Julia thread
        raw = ZMQ.recv(socket, ZMQ.DONTWAIT) 
        msg = JSON.parse(String(raw))
        # R4-01: Correct Atomic Exchange API
        Threads.atomic_xchg!(p_sigma, Float64(msg["sigma"]))
    catch e
        if !isa(e, ZMQ.StateError) # StateError = No data yet
            @warn "IPC Error: $e"
        end
    end
    sleep(0.001) # Yield to solver loop
end

function asr_dynamics!(du, u, p, t)
    alpha_eff = p_alpha - p_b/p_k
    if alpha_eff <= 0
        du[1] = -u[1] 
        return
    end
    du[1] = alpha_eff * u[1] - u[1]^3
end

function noise_diffusion(u, p, t)
    return p_sigma[] # R4-01: Correct Atomic Loading API
end

# CONTINUOUS WARM-START LOOP
current_u = [0.632] # Stable minimum sqrt(0.4)
while true
    tspan = (0.0, 0.01)
    # R4-04: Explicit parameter passing
    prob = SDEProblem(asr_dynamics!, noise_diffusion, current_u, tspan)
    sol = solve(prob, SRIW1(), adaptive=true, dtmax=0.001)
    global current_u = [sol[end][1]]
    yield()
end
