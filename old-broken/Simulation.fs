open System
open Microsoft.Xna.Framework
open Microsoft.Xna.Framework.Graphics

open Types
open Quadtree

type Simulation () as this =
    inherit Game ()

    let gd = new GraphicsDeviceManager (this)
    let mutable camera = Unchecked.defaultof<Camera2D>
    let mutable sprite_batch = null
    let mutable pixel = null
    let mutable basic_effect = null

    let mutable draw_qtree = true
    let mutable draw_bodies_solid = true
    let mutable draw_bodies_outline = false

    let rng = new Random ()
    let rand_float() = float32 (rng.NextDouble())

    let width = 1000f
    let height = 800f
    let body_count = 5000

    let boundaries = { Centre = Vector2.Zero; HalfSize = Vector2(width / 2f, height / 2f) }
    let world = World.create width height boundaries

    let bodies = [|
        for _ in 1..body_count do
            let s, v, a =
                Vector2(rand_float() * width - width/2.f, rand_float() * height - height/2.f),
                Vector2(rand_float()-0.5f,rand_float()-0.5f) * 50f,
                Vector2(rand_float()-0.5f,rand_float()-0.5f) * 1f
            let m = rand_float() * 0.5f + 0.5f
            let body = Body(s, v, a, m, 0.25f * m)
            ignore <| World.add_body body world
    |]

    do
        gd.PreferredBackBufferWidth <- 1100
        gd.PreferredBackBufferHeight <- 900
        this.IsMouseVisible <- true

    override this.LoadContent (): unit = 

        sprite_batch <- new SpriteBatch(this.GraphicsDevice)
        pixel <- Draw.make_pixel this.GraphicsDevice
        camera <- new Camera2D(this.GraphicsDevice.Viewport)
        fun _ -> camera.Viewport <- this.GraphicsDevice.Viewport
        |> this.Window.ClientSizeChanged.Add
        basic_effect <- new BasicEffect(this.GraphicsDevice)

        this.Window.AllowUserResizing <- true

        for body in bodies do
            Quadtree.insert body world.Quadtree |> ignore

        base.LoadContent()

    override this.Update (gameTime: GameTime): unit = 
        if Input.Keyboard.GetState().IsKeyDown Input.Keys.Escape then this.Exit()

        if Input.Keyboard.GetState().IsKeyDown Input.Keys.F1 then draw_bodies_solid <- not draw_bodies_solid
        if Input.Keyboard.GetState().IsKeyDown Input.Keys.F2 then draw_bodies_outline <- not draw_bodies_outline
        if Input.Keyboard.GetState().IsKeyDown Input.Keys.F3 then draw_qtree <- not draw_qtree

        let dt = float32 gameTime.ElapsedGameTime.TotalSeconds

        world
        |> World.update dt
        |> ignore


        //printfn $"---------------- Quadtree ----------------"
        //printfn $"{world.Quadtree}"
        //printfn $""

        base.Update(gameTime: GameTime)

    override this.Draw (gameTime: GameTime): unit = 

        this.GraphicsDevice.Clear Colour.Black
        
        camera.Position <- Vector2.Zero

        sprite_batch.Begin(
            transformMatrix = camera.GetMatrix(),
            samplerState = SamplerState.PointClamp
        )
        
        Draw.axes sprite_batch pixel 500.f

        Draw.grid sprite_batch pixel 25.f 40 (Colour(50,50,50))
        
        if draw_qtree then
            Draw.quadtree sprite_batch pixel world.Quadtree Colour.CornflowerBlue 0

        if draw_bodies_solid then
            Draw.draw_circles basic_effect gd.GraphicsDevice camera

        //    for body in world.Bodies do
        //        Draw.solid_circle
        //            sprite_batch
        //            pixel
        //            body.Position
        //            body.Radius
        //            32
        //            Colour.Yellow

        //if draw_bodies_outline then
        //    for body in world.Bodies do
        //        Draw.circle
        //            sprite_batch
        //            pixel
        //            body.Position
        //            body.Radius
        //            32
        //            Colour.Orange

        sprite_batch.End()

        base.Draw(gameTime: GameTime)

[<EntryPoint>]
let main _ =
    use g = new Simulation()
    g.Run()
    0

