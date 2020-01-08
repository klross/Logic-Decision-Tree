structure BarnesHut =
struct

  open Mechanics
  structure BB = BoundingBox
  open Plane
  open TestData

  infixr 3 ++
  infixr 4 **
  infixr 4 //
  infixr 3 -->

  datatype bhtree =
      Empty
    | Single of body
    | Cell of (Scalar.scalar * Plane.point) * BB.bbox * bhtree * bhtree * bhtree * bhtree
      (* ((mass, center), box, top-left, top-right, bottom-left, bottom-right) *)

  (* Projects the mass and center from the root node of a bhtree *)
  fun center_of_mass (T : bhtree) : Scalar.scalar * Plane.point =
      case T of
          Empty => (Scalar.zero, Plane.origin)
        | Single (m, p, _) => (m, p)
        | Cell (com, _, _,_,_,_) => com

  (* Note: Doesn't compare velocities as these are unaffected by compute_tree *)
  fun bodyEq ((m1, p1, _) : body, (m2, p2, _) : body) : bool =
      (Scalar.eq (m1, m2)) andalso Plane.pointEqual (p1, p2)

  fun bhtreeEq (t1 : bhtree, t2 : bhtree) : bool =
      case (t1, t2) of
          (Empty, Empty) => true
        | (Single b1, Single b2) => bodyEq (b1, b2)
        | (Cell ((cm1, cp1), bb1, tl1,tr1,bl1,br1), Cell ((cm2, cp2), bb2, tl2,tr2,bl2,br2)) =>
              Scalar.eq (cm1, cm2) andalso
              Plane.pointEqual (cp1, cp2) andalso
              BB.equal (bb1, bb2) andalso 
              bhtreeEq (tl1,tl2) andalso bhtreeEq (tr1,tr2) andalso 
              bhtreeEq (bl1,bl2) andalso bhtreeEq (br1,br2)
        | (_, _) => false

  (* ---------------------------------------------------------------------- *)
  (* TASKS *)

  (* TASK *)
  (* Compute the barycenter of four points.
     Assumes that all points have nonnegative mass, and 
     that at least one point has strictly positive mass. *)
  fun barycenter ((m1,p1) : (Scalar.scalar * Plane.point),
                  (m2,p2) : (Scalar.scalar * Plane.point),
                  (m3,p3) : (Scalar.scalar * Plane.point),
                  (m4,p4) : (Scalar.scalar * Plane.point)) : Scalar.scalar * Plane.point =
    let val m = Scalar.plus (Scalar.plus(m1,m2), Scalar.plus(m3,m4) ) 
    	val vec1 = Plane.-->(Plane.origin, p1) 
    	val vec2 = Plane.-->(Plane.origin, p2) 
    	val vec3 = Plane.-->(Plane.origin, p3) 
    	val vec4 = Plane.-->(Plane.origin, p4) 
    	val c1 = Plane.**(vec1, m1)
    	val c2 = Plane.**(vec2, m2)
    	val c3 = Plane.**(vec3, m3)
    	val c4 = Plane.**(vec4, m4)
    	val total = Plane.++(Plane.++(c1,c2), Plane.++(c3,c4) )
    	val c = Plane.//(total, m)
      in
      	(m, Plane.head(c))
      end

  fun test_barycenter() =
      let 
          val (barymass,baryloc) =
              barycenter ((Scalar.one,p00), (Scalar.one,p02), (Scalar.one,p01), (Scalar.plus(Scalar.one,Scalar.one),p44))
      in
          (testb "bmass" (Scalar.eq(barymass, Scalar.fromInt 5)) true;
           testb "bloc" (Plane.pointEqual(baryloc, Plane.fromcoord(Scalar.fromRatio(8,5), Scalar.fromRatio(11,5)))) true)
      end

  (* TASK *)
  (*Compute the four quadrants of the bounding box *)

  fun quarters (bb : BB.bbox) : BB.bbox * BB.bbox * BB.bbox * BB.bbox =
  	let 
      val (c1,c2,c3,c4) = BB.corners(bb)
      val c = BB.center(bb)
    	val bbtopleft = BB.from2Points(c1,c)
    	val bbtopright = BB.from2Points(c2,c)
    	val bbbottomleft = BB.from2Points(c3,c)
      val bbbottomright = BB.from2Points(c4,c)
    in (bbtopleft, bbtopright, bbbottomleft, bbbottomright)
    end 


  (* Test for quarters: *)
  fun test_quarters() =
      testb "q1" (let val (tl,tr,bl,br) = quarters(bb4) 
                  in BB.equal(tl,bb0) andalso BB.equal(tr,bb1) andalso
                      BB.equal(bl, bb2) andalso BB.equal(br,bb3)
                  end) true

  (* TASK *)
  (* Computes the Barnes-Hut tree for the bodies in the given sequence.
   * Assumes all the bodies are contained in the given bounding box,
     and that no two bodies have collided (or are so close that dividing the 
     bounding box will not eventually separate them).
     *)



  fun compute_tree (s : body Seq.seq) (bb : BB.bbox) : bhtree = 
    case Seq.length s of
      0 => Empty
      |1 => Single (Seq.nth 0 s) 
      |_ => let val (q1,q2,q3,q4) = quarters(bb)
        val seq1 = Seq.filter ( fn(_, p, _) => BB.contained (false, false,false, false) (p, q1) ) s
        val seq2 = Seq.filter ( fn(_, p, _) => BB.contained (true, false,false, false) (p, q2) ) s
        val seq3 = Seq.filter ( fn(_, p, _) => BB.contained (false, false, true, false) (p, q3) ) s
        val seq4 = Seq.filter ( fn(_, p, _) => BB.contained (true, false , true, false) (p, q4) ) s
        val t1 = compute_tree (seq1) (q1)
        val t2 = compute_tree (seq2) (q2)
        val t3 = compute_tree (seq3) (q3)
        val t4 = compute_tree (seq4) (q4)
        val  bar = barycenter (center_of_mass(t1), center_of_mass(t2), center_of_mass(t3), center_of_mass(t4) )
      in
        Cell(bar, bb, t1,t2, t3, t4)
      end



        

  (* Test for compute_tree: *)
  fun test_compute_tree() =
      let 
          val three_bodies = Seq.cons body1 (Seq.cons body2 (Seq.cons body3 (Seq.empty())))
          val three_bodies_tree = Cell ((Scalar.fromInt 3, p22), bb4,
                                        Cell ((Scalar.fromInt 2, p13), bb0,
                                              Single body3, Empty, Empty, Single body2), 
                                        Empty, 
                                        Empty, 
                                        Single body1)
      in
          testb "c1" (bhtreeEq (compute_tree three_bodies bb4, three_bodies_tree)) true
      end

  (* TASK *)
  (* too_far p1 p2 bb t determines if point p1 is "too far" from 
   * a region bb with barycenter p2, given a threshold parameter t,
   * for it to be worth recuring into the region
   *)
  fun too_far (p1 : Plane.point) (p2 : Plane.point) (bb : BB.bbox) (t : Scalar.scalar) : bool = 
      let val diam = BB.diameter(bb)
        val dist = Plane.distance p1 p2
        val denom= Scalar.divide(diam,dist)
      in
         Scalar.lte(denom,t)
       end 

  (* TASK *)
  (* Computes the acceleration on b from the tree T using the Barnes-Hut
   * algorithm with threshold t
   *)
  fun bh_acceleration (T : bhtree) (t : Scalar.scalar) (b : body) : Plane.vec = 
    case T of
      Empty => zero
      |Single(bod) => Mechanics.accOn(b, bod)
      |Cell((m,c), bb, q1, q2, q3, q4) => let
        val (mass, pos, vel) = b
      in
        (case too_far pos c bb t of 
          true => Mechanics.accOn(b, (m, c, zero))
          | false => Plane.++(Plane.++ (bh_acceleration q1 t b, bh_acceleration q2 t b), Plane.++(bh_acceleration q3 t b, bh_acceleration q4 t b  ))
          )
        end 




  (* TASK
     Given a threshold and a sequence of bodies, compute the acceleration
     on each body using the Barnes-Hut algorithm.
   *)
  fun barnes_hut (threshold : Scalar.scalar) (s : body Seq.seq) : Plane.vec Seq.seq = 
        let val pos_s = Seq.map (fn (_,p,_) => p) s
        val bb = BB.fromPoints pos_s
        val bh_tree = compute_tree s bb
      in 
        Seq.map (fn b => bh_acceleration bh_tree threshold b ) s
      end
        

  (* Default value of the threshold, theta = 0.5 *)
  val threshold = (Scalar.fromRatio (1,2))

  val accelerations : body Seq.seq -> Plane.vec Seq.seq = barnes_hut threshold

end
