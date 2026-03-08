[<RequireQualifiedAccess>]
module World

open Types
open Quadtree
open Quadtree
open Body

let create w h boundaries =
  { Bodies = ResizeArray()
    Pool = init_pool Quadtree.MAX_NODES Quadtree.CAPACITY
    //Quadtree = Quadtree.create boundaries Quadtree.capacity
    Width = w 
    Height = h }

let refresh_tree (world: World) = 
    world.Quadtree <- Quadtree.create world.Quadtree.Boundary world.Quadtree.Capacity
    QuadtreePool.refresh world.Pool
    for body in world.Bodies do
        Quadtree.insert body world.Quadtree |> ignore

let update_size w h world =
    world.Width <- w
    world.Height <- h

let update (dt: float32) (world: World) = 

    let accels = Gravity.compute_accels_BH_multi world.Bodies

    for i in 0..world.Bodies.Count - 1 do
        world.Bodies.[i].IntegrateVerlet(accels[i], dt)

    refresh_tree world

    Collision.check world

let add_body body world = 
    world.Bodies.Add body
    Quadtree.insert body world.Quadtree