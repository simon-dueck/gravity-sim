module Input

open System

open Microsoft.Xna.Framework
open Microsoft.Xna.Framework.Input

open Types

let private clamp lower upper value = min upper (max lower value)

type Controls =
    | Exit = 0
    | Confirm = 19
    | Back = 20
    | Forward = 3
    | TurnLeft = 1
    | TurnRight = 2
    | Shoot = 4
    | Pause = 5
    | RMouse = 6
    | LMouse = 7
    | ZoomIn = 8
    | ZoomOut = 9
    | PanUp = 10
    | PanDown = 11
    | PanLeft = 12
    | PanRight = 13
    | Action1 = 14
    | Action2 = 15
    | Action3 = 16
    | Action4 = 17
    | Action5 = 18

let init: InputState = 

    let size =
        Enum.GetValues typeof<Controls>
        |> Seq.cast<int>
        |> Seq.max

    { States = Array.zeroCreate size; Keys = Array.zeroCreate size }
    

let read (new_state: KeyboardState) (input: InputState) =
    let iter i key = 
        match new_state.IsKeyDown key with
        | true -> input.States.[i] <- clamp 1 255 (input.States.[i] + 1)
        | false -> input.States.[i] <- clamp -1 -255 (input.States.[i] - 1)

    Array.iteri iter input.Keys

let rebind (control: int) (key: Keys) (input: InputState) =
    input.Keys.[control] <- key

let buffered_down (ctrl: Controls) (buffer: int) (input: InputState) =
    let i = int ctrl

    input.States.[i] > 0 && input.States.[i] <= buffer

