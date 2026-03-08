[<RequireQualifiedAccess>]
module AABB

open Microsoft.Xna.Framework

open Types

let contains (aabb: AABB) (pos: Vector2) =
    abs (pos.X - aabb.Centre.X) <= aabb.HalfSize.X
    && abs (pos.Y - aabb.Centre.Y) <= aabb.HalfSize.Y

let intersects (a: AABB) (b: AABB) =
    abs (a.Centre.X - b.Centre.X) <= a.HalfSize.X + b.HalfSize.X
    && abs (a.Centre.Y - b.Centre.Y) <= a.HalfSize.Y + b.HalfSize.Y