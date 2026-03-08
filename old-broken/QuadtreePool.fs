module Quadtree

open Microsoft.Xna.Framework

open Types
open AABB
open Body

let MAX_NODES = 15000
let CAPACITY = 4

let init_pool nodes capacity = 
    Array.init nodes (fun _ ->
      { Boundary = Unchecked.defaultof<AABB>
        Count = 0
        Bodies = Array.zeroCreate capacity
        Mass = 0f
        CentreOfMass = Vector2.Zero
        Divided = false
        NE = -1
        NW = -1
        SE = -1
        SW = -1 }
    )

let mutable index = 0

let reset () = index <- 0

let alloc () = 
    // get a new node
    let node = index
    index <- index + 1
    
    // reset the node
    pool.[node].Count <- 0
    pool.[node].Divided <- false
    pool.[node].Mass <- 0f
    pool.[node].CentreOfMass <- Vector2.Zero

    node

let build_root_tree (center: Vector2) (half: Vector2) =
    reset()
    let root = alloc()
    pool.[root].Boundary <- { Centre = center; HalfSize = half }
    root

let subdivide (node: int) =
    let c = pool.[node].Boundary.Centre
    let h = pool.[node].Boundary.HalfSize * 0.5f

    let init_sub dx dy =
        let child = alloc()
        pool.[child].Boundary <- { Centre = c + Vector2(dx*h.X, dy*h.Y); HalfSize = h }
        child

    pool.[node].NE <- init_sub 1f -1f
    pool.[node].NW <- init_sub -1f -1f
    pool.[node].SE <- init_sub 1f 1f
    pool.[node].SW <- init_sub -1f 1f
    pool.[node].Divided <- true

let rec insert (node: int) (body: Body) =
    if not (AABB.contains pool.[node].Boundary body.Position) then false
    else
        if pool.[node].Count < CAPACITY && not pool.[node].Divided then
            pool.[node].Bodies[pool.[node].Count] <- body
            pool.[node].Count <- pool.[node].Count + 1
            true
        else
            if not pool.[node].Divided then subdivide node
            insert pool.[node].NE body ||
            insert pool.[node].NW body ||
            insert pool.[node].SE body ||
            insert pool.[node].SW body