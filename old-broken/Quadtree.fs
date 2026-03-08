module QuadtreeAlloc

open Microsoft.Xna.Framework

open Types
open Body
open AABB

let capacity = 10

let create boundary capacity =
  { Boundary = boundary
    Capacity = capacity
    Bodies = ResizeArray()
    Divided = false
    TotalMass = 0f
    CentreOfMass = Vector2.Zero
    NE = None
    NW = None
    SE = None
    SW = None }

// get sequence of all bodies in the quadtree
let bodies (qt: Quadtree): Body seq =
    
    let rec sub (qto: Quadtree option) =
        seq {
            match qto with
            | Some t ->
                if not t.Divided then
                    yield! t.Bodies
                else
                    yield! sub t.NE
                    yield! sub t.NW
                    yield! sub t.SE
                    yield! sub t.SW
            | None -> yield! Seq.empty
        }

    qt |> Some |> sub

let rec private subdivide (qt: Quadtree) =
    
    let centre = qt.Boundary.Centre
    let new_halfsize = qt.Boundary.HalfSize / 2.f
    
    // helper function to make each subquadtree
    let init_sub x y =
      { Boundary =
          { Centre = centre + Vector2(x * new_halfsize.X, y * new_halfsize.Y)
            HalfSize = new_halfsize }
        Capacity = qt.Capacity
        Bodies = ResizeArray()
        Divided = false
        TotalMass = 0f
        CentreOfMass = Vector2.Zero
        NE = None
        NW = None
        SE = None
        SW = None }
    
    // label this quadtree as divided
    qt.Divided <- true

    // make each subquadtree
    qt.NE <- Some (init_sub 1f -1f)
    qt.NW <- Some (init_sub -1f -1f)
    qt.SE <- Some (init_sub 1f 1f)
    qt.SW <- Some (init_sub -1f 1f)

    // move all bodies into subtrees
    for body in qt.Bodies do
        ignore <| insert body qt

    //qt.Bodies.Clear()

and insert (body: Body) (qt: Quadtree) =
    
    // check if it even goes in this one
    if not (AABB.contains qt.Boundary body.Position) then false
    
    else

        // check if isn't divided and has capacity
        if not qt.Divided && qt.Bodies.Count < qt.Capacity then
            
            qt.Bodies.Add body
            qt.TotalMass <- qt.TotalMass + body.Mass
            qt.CentreOfMass <- (qt.CentreOfMass * qt.TotalMass + body.Position * body.Mass) / qt.TotalMass
            
            true

        // if it's full
        else
            // subdivide it if it isn't subdivided
            if not qt.Divided then subdivide qt

            // insert the body into the now subdivided quadtree
            let mutable inserted = false
            if qt.NE.IsSome && insert body qt.NE.Value then inserted <- true
            elif qt.NW.IsSome && insert body qt.NW.Value then inserted <- true
            elif qt.SE.IsSome && insert body qt.SE.Value then inserted <- true
            elif qt.SW.IsSome && insert body qt.SW.Value then inserted <- true

            if inserted then
                let totalMass = qt.TotalMass + body.Mass
                qt.CentreOfMass <- (qt.CentreOfMass * qt.TotalMass + body.Position * body.Mass) / totalMass
                qt.TotalMass <- totalMass
                
            inserted

let rec query (qt: Quadtree) (range: AABB) (found: ResizeArray<Body>) =
    if not (AABB.intersects qt.Boundary range) then ()
    else
        for b in qt.Bodies do
            found.Add b

        if qt.Divided then
            query qt.NE.Value range found
            query qt.NW.Value range found
            query qt.SE.Value range found
            query qt.SW.Value range found