[<RequireQualifiedAccess>]
module Collision

open System
open System.Threading.Tasks

open Microsoft.Xna.Framework

open Types
open Body
open Quadtree

let private flip_x (vec: Vector2) = new Vector2(-vec.X, vec.Y)
let private flip_y (vec: Vector2) = new Vector2(vec.X, -vec.Y)

let collide (a: int) (b: int) =
    
    let delta = b.Position - a.Position
    let dist = delta.Length()
    let minimum_distance = a.Radius + b.Radius

    if dist < 1e-4f then () // avoid division by small numbers
    elif dist < minimum_distance then

        // Move apart
        let normal = Vector2.Normalize delta
        let overlap = minimum_distance - dist
        let correction = 0.5f * overlap * normal

        a.Position <- a.Position - correction
        b.Position <- b.Position + correction

        let diff_s = a.Position - b.Position
        let diff_v = a.Velocity - b.Velocity
        let mag_diff_2 = diff_s.LengthSquared()

        a.Velocity <- a.Velocity - 2f * b.Mass / (a.Mass + b.Mass) * Vector2.Dot(diff_v, diff_s) / mag_diff_2 * diff_s
        b.Velocity <- b.Velocity + 2f * a.Mass / (a.Mass + b.Mass) * Vector2.Dot(-diff_v, -diff_s) / mag_diff_2 * diff_s

let check_bounds w h (body: Body) =
        let radius = body.Radius

        let hw = w/2f
        let hh = h/2f

        // Left / Right
        if body.Position.X - radius < -hw then
            body.Position <- Vector2(radius - hw, body.Position.Y)
            body.Velocity <- flip_x body.Velocity

        elif body.Position.X + radius > hw then
            body.Position <- Vector2(hw - radius, body.Position.Y)
            body.Velocity <- flip_x body.Velocity

        // Bottom / Top
        if body.Position.Y - radius < -hh then
            body.Position <- Vector2(body.Position.X, radius - hh)
            body.Velocity <- flip_y body.Velocity
        elif body.Position.Y + radius > hh then
            body.Position <- Vector2(body.Position.X, hh - radius)
            body.Velocity <- flip_y body.Velocity

let check world =

    let bodies = world.Bodies

    for b in bodies do
        let range: AABB =
          { Centre = b.Position
            HalfSize = Vector2(b.Radius * 2f, b.Radius * 2f) }
        
        let nearby = ResizeArray<Body>()
        
        Quadtree.query world.Quadtree range nearby

        for other in nearby do
            if not (obj.ReferenceEquals(b, other)) then
                collide b other

        check_bounds world.Width world.Height b