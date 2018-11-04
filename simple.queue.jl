#! /opt/julia/julia

using ResumableFunctions
using Distributions
using Random
using SimJulia

Random.seed!(123) # Set the seed for repeatability between test runs


lambda                = 1 # arrival rate per client
interArrivalDelayDist = Distributions.Exponential(1/lambda)
serviceDemand         = 0.10 # seconds
serviceDemandDist     = Distributions.Exponential(serviceDemand)

outputReport   = open("output.simple.queue.data.csv", "w")

println("Starting")

@resumable function requestQueue(sim::Environment, simpleQueue, id, numClients)
  while true

    interArrivalDelay = rand(interArrivalDelayDist)
    serviceDemand     = rand(serviceDemandDist)

    @yield timeout(sim, interArrivalDelay) # interarrival delay time period

    push!(totalHits, 1)

    entryTime = now(sim)
    @yield request(simpleQueue) # Send request to queue

    W = now(sim) - entryTime
    Q = W/serviceDemand

    @yield timeout(sim, serviceDemand) # Hold queue for service demand time
    @yield release(simpleQueue)        # Done with queue. Others can now use it.

    residenceTime = now(sim) - entryTime

    RT  = now(sim) - entryTime
    C_S = RT - W

    push!(totalUtil, serviceDemand)
    push!(qArray, Q)
    push!(responseArray, RT)
    push!(totalWait, W)

  end
end

function runSimulation(maxClients, run_time)

    global responseArray = []
    global qArray        = []
    global totalHits     = []
    global totalUtil     = []
    global totalWait     = []

    sim           = Simulation()
    simpleQueue   = Resource(sim, 1)

    for i = 1:maxClients
      @process requestQueue(sim, simpleQueue, i, maxClients)
    end

    run(sim, run_time)

    avgR        = mean(responseArray)
    avgQ        = mean(qArray)
    avgW        = mean(totalWait)
    avgS        = mean(totalUtil)
    avgLambda   = sum(totalHits)/run_time
    rho         = sum(totalUtil)/run_time
    computedRho = avgLambda * serviceDemand
    computedR   = serviceDemand/(1-computedRho)

    println(outputReport, "$maxClients,$run_time,$avgLambda,$rho,$computedRho,$avgQ,$avgW,$avgS,$avgR,$computedR")

end

println(outputReport, "numClients,simulationSeconds,DES_Lambda,DES_Rho,computed_Rho,DES_Q,DES_W,DES_s,DES_R,computedR")

for i in 1:20
  for j in 1:24
    println("Running with $i client count for $j hours.")
    runSimulation(i, j*3600)
  end
end

println("Done.")

close(outputReport)
