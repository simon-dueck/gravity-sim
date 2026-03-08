module Types

open Microsoft.Xna.Framework
open Microsoft.Xna.Framework.Graphics

type InputState =
  { States : int array
    Keys : Input.Keys array }

[<Struct>]
type Body =

    val mutable private pos : Vector2
    val mutable private vel : Vector2
    val mutable private acc : Vector2
    val private mass : float32
    val private radius : float32

    new (position: Vector2,
         velocity: Vector2,
         accel: Vector2,
         mass: float32,
         radius: float32) =
        {
            pos = position
            vel = velocity
            acc = accel
            mass = mass
            radius = radius
        }

    member this.Mass = this.mass
    member this.Radius = this.radius

    member this.Position
        with get() = this.pos
        and set s = this.pos <- s
    member this.Velocity
        with get() = this.vel
        and set v = this.vel <- v
    member this.Acceleration
        with get() = this.acc
        and set a = this.acc <- a

    member this.Momentum = this.mass * this.vel
    member this.Energy = 0.5f * this.mass * this.vel * this.vel

    member this.Integrate(new_accel: Vector2, dt: float32) =
        this.vel <- this.vel + new_accel * dt
        this.pos <- this.pos + this.vel * dt

    member this.IntegrateVerlet(new_accel: Vector2, dt: float32) =
        this.pos <- this.pos + this.vel * dt + 0.5f * this.acc * dt * dt
        this.vel <- this.vel + 0.5f * (this.acc + new_accel) * dt
        this.acc <- new_accel

[<Struct>]
type AABB =
    { Centre : Vector2
      HalfSize : Vector2 }

type Quadtree =
    { Boundary : AABB
      Capacity : int
      mutable Bodies : ResizeArray<Body>
      mutable TotalMass : float32
      mutable CentreOfMass : Vector2
      mutable Divided : bool
      mutable NE : Quadtree option
      mutable NW : Quadtree option
      mutable SE : Quadtree option
      mutable SW : Quadtree option }

[<Struct>]
type QuadtreeNode =
    { mutable Boundary : AABB
      mutable Count : int
      Bodies : Body array
      mutable Mass : float32
      mutable CentreOfMass : Vector2
      mutable Divided : bool
      mutable NE : int
      mutable NW : int
      mutable SE : int
      mutable SW : int }

type World =
  { Bodies : ResizeArray<Body>
    Pool : QuadtreeNode array
    mutable Width : float32
    mutable Height : float32 }

type Camera2D(vp: Viewport) =

    let mutable viewport = vp
    let mutable position = Vector2.Zero   // world coords
    let mutable zoom = 1.0f

    member _.Viewport
        with get() = viewport
        and set v = viewport <- v

    member _.Position
        with get() = position
        and set v = position <- v

    member _.Zoom
        with get() = zoom
        and set z = zoom <- max 0.01f z

    member _.GetMatrix() =
        Matrix.CreateTranslation(-position.X, -position.Y, 0.f) *
        Matrix.CreateScale(zoom, zoom, 1.f) *
        Matrix.CreateTranslation(
            float32 viewport.Width * 0.5f,
            float32 viewport.Height * 0.5f,
            0.f
        )

type Colour = Color