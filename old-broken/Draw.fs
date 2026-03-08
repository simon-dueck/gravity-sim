[<RequireQualifiedAccess>]
module Draw

open Microsoft.Xna.Framework
open Microsoft.Xna.Framework.Graphics
open System

open Types

let make_pixel (gd: GraphicsDevice) =
    let tex = new Texture2D(gd, 1, 1)
    tex.SetData([| Colour.White |])
    tex

let line p1 p2 colour (be: BasicEffect) (gd: GraphicsDevice) =
    let vertices =
     [| VertexPositionColor(Vector3(p1,0f), colour)
        VertexPositionColor(Vector3(p2,0f), colour) |]

    for pass in be.CurrentTechnique.Passes do
        pass.Apply()
        gd.DrawUserPrimitives(
            PrimitiveType.LineList,
            vertices,
            0,
            1
        )

let circle (sb: SpriteBatch) (pixel: Texture2D) (center: Vector2) (radius: float32) (segments: int) (colour: Colour) =

    let step = MathHelper.TwoPi / float32 segments

    let mutable prev =
        center + Vector2(radius, 0.f)

    for i = 1 to segments do
        let theta = float32 i * step
        let next =
            center + Vector2(
                cos theta * radius,
                sin theta * radius
            )

        let edge = next - prev
        let length = edge.Length()
        let rotation = atan2 edge.Y edge.X

        sb.Draw(
            pixel,
            prev,
            Nullable(),
            colour,
            rotation,
            Vector2.Zero,
            Vector2(length, 1.f),
            SpriteEffects.None,
            0.f
        )

        prev <- next

let MAX_CIRCLES = 10000
let SEGMENTS = 16
let VERTS_PER = SEGMENTS * 3
let vertices =
    Array.zeroCreate<VertexPositionColor>(MAX_CIRCLES * VERTS_PER)

let mutable vertCount = 0
let addCircle (center: Vector2) (radius: float32) (color: Color) =
    let step = MathF.Tau / float32 SEGMENTS
    for i in 0 .. SEGMENTS-1 do
        let a0 = step * float32 i
        let a1 = step * float32 (i+1)

        vertices[vertCount] <- VertexPositionColor(Vector3(center.X, center.Y, 0.f), color)
        vertCount <- vertCount + 1

        vertices[vertCount] <- VertexPositionColor(Vector3(center.X + MathF.Cos(a0)*radius, center.Y + MathF.Sin(a0)*radius, 0.f), color)
        vertCount <- vertCount + 1

        vertices[vertCount] <- VertexPositionColor(Vector3(center.X + MathF.Cos(a1)*radius, center.Y + MathF.Sin(a1)*radius, 0.f), color)
        vertCount <- vertCount + 1

let draw_circles (basic_effect: BasicEffect) (graphics_device: GraphicsDevice) (camera: Camera2D) =
    basic_effect.World <- camera.GetMatrix()
    basic_effect.View <- Matrix.Identity
    basic_effect.Projection <- Matrix.CreateOrthographicOffCenter(
        0.f, float32 camera.Viewport.Width,
        float32 camera.Viewport.Height, 0.f,
        0.f, 1.f)

    basic_effect.VertexColorEnabled <- true

    for pass in basic_effect.CurrentTechnique.Passes do
        pass.Apply()
        graphics_device.DrawUserPrimitives(
            PrimitiveType.TriangleList,
            vertices,
            0,
            vertCount / 3
        )

    vertCount <- 0

let solid_circle (sb: SpriteBatch) (pixel: Texture2D) (center: Vector2) (radius: float32) (segments: int) (colour: Colour) =

    let step = MathHelper.TwoPi / float32 segments

    let r = int (Math.Ceiling(float radius))

    for y = -r to r do
        let dy = float32 y
        let dx = sqrt (radius * radius - dy * dy)
        let x0 = center.X - dx
        let lineWidth = dx * 2.f

        sb.Draw(
            pixel,
            Vector2(x0, center.Y + dy),
            Nullable(),
            colour,
            0.f,
            Vector2.Zero,
            Vector2(lineWidth, 1.f),
            SpriteEffects.None,
            0.f
        )

let aabb (sb: SpriteBatch) (pixel: Texture2D) (bounds: AABB) (colour: Colour) (depth: int) =

    let c = bounds.Centre
    let h = bounds.HalfSize

    let min = c - h
    let max = c + h

    let w = max.X - min.X
    let hgt = max.Y - min.Y

    // top
    sb.Draw(pixel, min, Nullable(), colour, 0.f, Vector2.Zero, Vector2(w, 1.f), SpriteEffects.None, 0.f)
    // bottom
    sb.Draw(pixel, Vector2(min.X, max.Y), Nullable(), colour, 0.f, Vector2.Zero, Vector2(w, 1.f), SpriteEffects.None, 0.f)
    // left
    sb.Draw(pixel, min, Nullable(), colour, 0.f, Vector2.Zero, Vector2(1.f, hgt), SpriteEffects.None, 0.f)
    // right
    sb.Draw(pixel, Vector2(max.X, min.Y), Nullable(), colour, 0.f, Vector2.Zero, Vector2(1.f, hgt), SpriteEffects.None, 0.f)

let rec quadtree (sb: SpriteBatch) (pixel: Texture2D) (qt: Quadtree) (colour: Colour) (depth: int) =

    aabb sb pixel qt.Boundary colour depth

    if qt.Divided then
        qt.NE |> Option.iter (fun n -> quadtree sb pixel n colour (depth + 1))
        qt.NW |> Option.iter (fun n -> quadtree sb pixel n colour (depth + 1))
        qt.SE |> Option.iter (fun n -> quadtree sb pixel n colour (depth + 1))
        qt.SW |> Option.iter (fun n -> quadtree sb pixel n colour (depth + 1))

let grid (sb: SpriteBatch) (pixel: Texture2D) (spacing: float32) (count: int) (colour: Colour) =

    let size = float32 count * spacing

    for i = -count to count do
        let p = float32 i * spacing

        // vertical lines
        sb.Draw(
            pixel,
            Vector2(p, -size),
            Nullable(),
            colour,
            0.f,
            Vector2.Zero,
            Vector2(1.f, size * 2.f),
            SpriteEffects.None,
            0.f
        )

        // horizontal lines
        sb.Draw(
            pixel,
            Vector2(-size, p),
            Nullable(),
            colour,
            0.f,
            Vector2.Zero,
            Vector2(size * 2.f, 1.f),
            SpriteEffects.None,
            0.f
        )

let axes (sb: SpriteBatch) (pixel: Texture2D) (length: float32) =

    // X axis (red)
    sb.Draw(
        pixel,
        Vector2(-length, 0.f),
        Nullable(),
        Colour.Red,
        0.f,
        Vector2.Zero,
        Vector2(length * 2.f, 2.f),
        SpriteEffects.None,
        0.f
    )

    // Y axis (green)
    sb.Draw(
        pixel,
        Vector2(0.f, -length),
        Nullable(),
        Colour.Green,
        0.f,
        Vector2.Zero,
        Vector2(2.f, length * 2.f),
        SpriteEffects.None,
        0.f
    )
