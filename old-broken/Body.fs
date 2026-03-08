module Body

open Types

open Microsoft.Xna.Framework

let generate (count: int) (width: float32) (height: float32) =
    let rng = System.Random()
    let randf() = float32 (rng.NextDouble())
    [|
        for i in 1..count do
            let x = randf() * width - width/2.f
            let y = randf() * height - height/2.f
            let pos = Vector2(x,y)
            let vel = Vector2(randf()-0.5f, randf()-0.5f) * 50.f
            let acc = Vector2.Zero
            let m = randf() * 5.f + 1.f
            yield Body(pos, vel, acc, m, 5.75f * m)
    |]