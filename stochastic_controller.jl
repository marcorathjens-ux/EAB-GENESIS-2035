using DifferentialEquations
using ZMQ, JSON

# ZMQ Bridge Setup
context = Context()
socket = Socket(context, PULL)
ZMQ.bind(socket, "tcp://*:5555")

function asr_dynamics!(du, u, p, t)
    alpha, b, k, sigma = p
    alpha_eff = alpha - b/k
    # GUARD: Ensure double-well potential exists
    if alpha_eff <= 0
        alpha_eff = 0.001 # Minimal recovery state
    end
    du[1] = alpha_eff * u[1] - u[1]^3
end

function noise_diffusion(u, p, t)
    return p[4] # Dynamic Sigma from ZMQ
end

# Optimized Start Point: Stable Minimum instead of Peak
p = [0.5, 0.1, 1.0, 0.15] # [alpha, b, k, sigma]
u0 = [sqrt(0.5 - 0.1/1.0)] # x0 = sqrt(alpha_eff)

tspan = (0.0, 1.0) # Small intervals for real-time sync
prob = SDEProblem(asr_dynamics!, noise_diffusion, u0, tspan, p)

println("Julia Controller V2.2: Awaiting ZMQ-data...")
# In a real loop, you would call: msg = JSON.parse(String(ZMQ.recv(socket)))
