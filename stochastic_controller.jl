using DifferentialEquations, ZMQ, JSON, Base.Threads

# CONFIGURATION (R3-06 Gap Closure)
const R0 = 0.45      # Base radius
const KAPPA = 0.08   # Exponential curvature factor
p_mutable = Threads.Atomic{Float64}(0.15) # Sigma (Noise)

# ZMQ SETUP (R3-01 & R3-02 Fix)
context = Context(); socket = Socket(context, PULL)
ZMQ.bind(socket, "tcp://*:5555")

# ASYNC RECEIVER (Non-blocking loop)
@async while true
    raw = ZMQ.recv(socket)
    msg = JSON.parse(String(raw))
    Threads.atomic_set!(p_mutable, msg["sigma"])
    yield() 
end

function asr_dynamics!(du, u, p, t)
    alpha, b, k = 0.5, 0.1, 1.0
    alpha_eff = alpha - b/k
    if alpha_eff <= 0 # R3-04 Safe Fallback
        du[1] = -u[1] 
        return
    end
    du[1] = alpha_eff * u[1] - u[1]^3
end

# CONTINUOUS SOLVE LOOP (R3-05 Warm-Start)
u_state = [sqrt(0.4)]
while true
    prob = SDEProblem(asr_dynamics!, (u,p,t)->Threads.atomic_get(p_mutable), u_state, (0.0, 0.01))
    sol = solve(prob, SRIW1(), adaptive=true, dtmax=0.001)
    global u_state = [sol[end][1]]
    # Sync with TENG-HW logic here
end
