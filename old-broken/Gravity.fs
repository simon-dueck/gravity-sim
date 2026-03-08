[<RequireQualifiedAccess>]
module Gravity

open System
open System.Threading.Tasks

open Microsoft.Xna.Framework

open Types
open Body
open Quadtree

let G = 987f
let θ = 0.5f
let ε = 0.5f

let inline private clamp x a b = max a (min b x)

let inline private smoothstep t =
    let t = clamp t 0.f 1.f
    t * t * (3.f - 2.f * t)

let compute_accels_single (bodies: ResizeArray<Body>) =

    let n = bodies.Count

    let accels = Array.zeroCreate n

    for i in 0..n - 1 do
        for j in i + 1..n - 1 do
            let bi = bodies[i]
            let bj = bodies[j]

            let epsilon = 0.5f * (bi.Radius + bj.Radius)

            let r = bj.Position - bi.Position

            let dist_squared = r.LengthSquared() + epsilon * epsilon
            if dist_squared > 0f then
                let inverse_dist = MathF.ReciprocalSqrtEstimate dist_squared
                let inverse_dist_cubed = inverse_dist * inverse_dist * inverse_dist

                let ti = min 1f (dist_squared / (bj.Radius * bj.Radius))
                let tj = min 1f (dist_squared / (bi.Radius * bi.Radius))

                let accel = G * r * inverse_dist_cubed

                accels[i] <- accels[i] + G * bj.Mass * inverse_dist_cubed * ti * r
                accels[j] <- accels[j] - G * bj.Mass * inverse_dist_cubed * ti * r

    accels

let compute_accels_multi (bodies: ResizeArray<Body>) =

    let n = bodies.Count

    let accels: Vector2 array = Array.zeroCreate n
    let accels_thread: Vector2 array array = Array.init Environment.ProcessorCount (fun _ -> Array.zeroCreate n)

    Parallel.For(0, n, fun i ->
    
        let accels_local = accels_thread.[Task.CurrentId.GetValueOrDefault() % accels_thread.Length]

        let bi = bodies.[i]
        for j in i+1..n-1 do
            let bj = bodies.[j]

            let epsilon = 0.5f * (bi.Radius + bj.Radius)

            let r = bj.Position - bi.Position

            let dist_squared = r.LengthSquared() + epsilon * epsilon
            if dist_squared > 0f then
                let inverse_dist = MathF.ReciprocalSqrtEstimate dist_squared
                let inverse_dist_cubed = inverse_dist * inverse_dist * inverse_dist

                let ti = min 1f (dist_squared / (bj.Radius * bj.Radius))
                let tj = min 1f (dist_squared / (bi.Radius * bi.Radius))

                let accel = G * r * inverse_dist_cubed

                accels_local[i] <- accels_local[i] + G * bj.Mass * inverse_dist_cubed * ti * r
                accels_local[j] <- accels_local[j] - G * bj.Mass * inverse_dist_cubed * ti * r

    ) |> ignore

    for accels_local in accels_thread do
        for k in 0..n-1 do
            accels.[k] <- accels.[k] + accels_local.[k]

    accels

let rec compute_accel_for_body_BH (qt: Quadtree) (body: Body) =
    let rVec = qt.CentreOfMass - body.Position
    let dist = rVec.Length()

    if dist = 0.f then Vector2.Zero
    else
        let s = qt.Boundary.HalfSize.X * 2.f
        let useApprox = s / dist < θ || not qt.Divided

        if useApprox then
            // branchless linear-inside-body factor
            let rSq = dist * dist + ε * ε
            let linearFactor = min 1.f (rSq / (qt.Boundary.HalfSize.X * qt.Boundary.HalfSize.X))
            let invDist = 1.f / sqrt rSq
            let invDist3 = invDist * invDist * invDist
            G * qt.TotalMass * rVec * invDist3 * linearFactor
        else
            let mutable accel = Vector2.Zero
            if qt.Divided then
                accel <- accel + compute_accel_for_body_BH qt.NE.Value body
                accel <- accel + compute_accel_for_body_BH qt.NW.Value body
                accel <- accel + compute_accel_for_body_BH qt.SE.Value body
                accel <- accel + compute_accel_for_body_BH qt.SW.Value body

            // also include bodies directly in this node
            for b in qt.Bodies do
                if not (obj.ReferenceEquals(b, body)) then
                    let dr = b.Position - body.Position
                    let distSq = dr.LengthSquared() + ε * ε
                    let invDist = 1.f / sqrt distSq
                    let invDist3 = invDist * invDist * invDist
                    let linearFactor = min 1.f (distSq / (b.Radius * b.Radius))
                    accel <- accel + G * b.Mass * dr * invDist3 * linearFactor
            accel

let rec compute_accel_for_body_BH_c1 (qt: Quadtree) (body: Body) =
    let r = qt.CentreOfMass - body.Position
    let dist = r.Length()

    if dist = 0.f then Vector2.Zero
    else
        let s = qt.Boundary.HalfSize.X * 2.f
        let ratio = s / dist

        let t0 = θ * 0.7f
        let t1 = θ * 1.3f

        let w =
            if not qt.Divided then 1.f
            else smoothstep ((t1 - ratio) / (t1 - t0))

        let r_squared = r.LengthSquared() + ε * ε
        let inverse_dist = 1.f / dist
        let inverse_dist_cubed = inverse_dist * inverse_dist * inverse_dist

        let lin_factor = min 1.f (r_squared / (qt.Boundary.HalfSize.X * qt.Boundary.HalfSize.X))

        let aggregate_force =
            G * qt.TotalMass * r * inverse_dist_cubed * lin_factor

        let mutable recForce = Vector2.Zero

        if qt.Divided then
            recForce <- recForce + compute_accel_for_body_BH qt.NE.Value body
            recForce <- recForce + compute_accel_for_body_BH qt.NW.Value body
            recForce <- recForce + compute_accel_for_body_BH qt.SE.Value body
            recForce <- recForce + compute_accel_for_body_BH qt.SW.Value body

        for b in qt.Bodies do
            if not (obj.ReferenceEquals(b, body)) then
                let dr = b.Position - body.Position
                let distSq = dr.LengthSquared() + ε * ε
                let inv = 1.f / sqrt distSq
                let inv3 = inv * inv * inv
                let lf = min 1.f (distSq / (b.Radius * b.Radius))
                recForce <- recForce + G * b.Mass * dr * inv3 * lf

        w * aggregate_force + (1.f - w) * recForce

let compute_accels_BH_multi (bodies: ResizeArray<Body>) =
    let n = bodies.Count

    // build quadtree
    let boundary = { Centre = Vector2.Zero; HalfSize = Vector2(1000.f, 1000.f) } // adjust to your sim

    let qt =
        { Boundary = boundary
          Capacity = 4
          Bodies = ResizeArray()
          Divided = false
          TotalMass = 0.f
          CentreOfMass = Vector2.Zero
          NE=None; NW=None; SE=None; SW=None }

    for b in bodies do Quadtree.insert b qt |> ignore

    // thread-local storage for safety
    let accels = Array.zeroCreate n
    let threadAccels = Array.init Environment.ProcessorCount (fun _ -> Array.zeroCreate n)

    // parallel loop
    Parallel.For(0, n, fun i ->
        let threadId = Task.CurrentId.Value % threadAccels.Length
        let localAccels = threadAccels.[threadId]
        localAccels.[i] <- compute_accel_for_body_BH_c1 qt bodies.[i]
    ) |> ignore

    // reduce thread-local arrays
    for tAcc in threadAccels do
        for k = 0 to n - 1 do
            accels.[k] <- accels.[k] + tAcc.[k]

    accels