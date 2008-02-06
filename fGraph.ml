open Format
open Ilist

(*  ********************************************************************** *)
(** {2 Polymorphic version} *)
(*  ********************************************************************** *)

type ('a,'b) node = {
    succ: 'a Sette.t;
    pred: 'a Sette.t;
    attrvertex: 'b
  }
type ('a,'b,'c,'d) graph = {
    nodes: ('a, ('a,'b) node) Mappe.t;
    arcs: ('a*'a,'c) Mappe.t;
    info: 'd;
  }

type ('a,'b,'c,'d) t = ('a,'b,'c,'d) graph

let info g = g.info
let set_info g info = { g with info=info }

let node g n = Mappe.find n g.nodes
let succ g n = (node g n).succ
let pred g n = (node g n).pred

let attrvertex g n = (node g n).attrvertex

let attredge g arc = Mappe.find arc g.arcs
let empty info = { nodes = Mappe.empty; arcs = Mappe.empty; info=info }
let size_vertex g = Mappe.cardinal g.nodes
let size_edge g = Mappe.cardinal g.arcs
let size g = (size_vertex g, size_edge g)

let is_empty g = (g.nodes = Mappe.empty)
let is_vertex g i =
  try let _ = node g i in true
  with Not_found -> false
let is_edge g arc =
  try let _ = Mappe.find arc g.arcs in true
  with Not_found -> false

let vertices g = Mappe.maptoset g.nodes
let edges g = Mappe.maptoset g.arcs

let map_vertex g f = { g with
  nodes =
  Mappe.mapi
    (fun v nv -> { nv with attrvertex = f v nv.attrvertex ~pred:nv.pred ~succ:nv.succ})
    g.nodes;
}
let iter_vertex g f = Mappe.iter (fun v nv -> f v nv.attrvertex ~pred:nv.pred ~succ:nv.succ) g.nodes
let fold_vertex g r f = Mappe.fold (fun v nv r -> f v nv.attrvertex ~pred:nv.pred ~succ:nv.succ r) g.nodes r
let map_edge g f = { g with
  arcs = Mappe.mapi f g.arcs
}
let iter_edge g f = Mappe.iter f g.arcs
let fold_edge g r f = Mappe.fold f g.arcs r

let map_info g f = { g with
  info = f g.info
}

let map g mapvertex mapedge mapinfo = {
  nodes = Mappe.mapi
  (fun v node -> { node with
    attrvertex = mapvertex v node.attrvertex ~pred:node.pred ~succ:node.succ;
  })
  g.nodes;
  arcs = Mappe.mapi mapedge g.arcs;
  info = mapinfo g.info;
}

let transpose g mapvertex mapedge mapinfo = {
  nodes = Mappe.mapi
  (fun v node -> {
    succ = node.pred;
    pred = node.succ;
    attrvertex = mapvertex v node.attrvertex ~pred:node.pred ~succ:node.succ;
  })
  g.nodes;
  arcs = Mappe.fold
  (begin fun ((x,y) as xy) attredge res ->
    Mappe.add (y,x) (mapedge xy attredge) res
  end)
  g.arcs Mappe.empty;
  info = mapinfo g.info;
}

let add_edge g ((a,b) as arc) attredge =
  try {
    nodes = begin
      if is_edge g arc then
	g.nodes
      else
	let na = node g a in
	if a=b then
	  Mappe.add a
	    { succ = Sette.add a na.succ; pred = Sette.add b na.pred; attrvertex = na.attrvertex }
	    g.nodes
	else
	  let nb = node g b in
	  Mappe.add a
	    { succ = Sette.add b na.succ; pred = na.pred; attrvertex = na.attrvertex }
	    (Mappe.add b
	      { succ = nb.succ; pred = Sette.add a nb.pred; attrvertex = nb.attrvertex }
	       g.nodes)
    end;
    arcs = Mappe.add arc attredge g.arcs;
    info = g.info;
  }
  with Not_found -> failwith "FGraph.add_edge"

let remove_edge g ((a,b) as arc) =
  if Mappe.mem arc g.arcs then
    try {
      nodes = begin
	let na = node g a in
	if a=b then
	  Mappe.add a
	    { succ = Sette.remove a na.succ; pred = Sette.remove a na.pred; attrvertex = na.attrvertex }
	    g.nodes
	else
	  let nb = node g b in
	  Mappe.add a
	    { succ = Sette.remove b na.succ; pred = na.pred; attrvertex = na.attrvertex }
	    (Mappe.add b
	      { succ = nb.succ; pred = Sette.remove a nb.pred; attrvertex = nb.attrvertex }
	      g.nodes)
      end;
      arcs = Mappe.remove arc g.arcs;
      info = g.info;
    }
    with Not_found -> failwith "FGraph.remove_edge"
  else
    g

let add_vertex g v attrvertex =
  try
    let anode = Mappe.find v g.nodes in
    { g with nodes = Mappe.add v { anode with attrvertex = attrvertex } g.nodes;}
  with Not_found ->
    { g with nodes = Mappe.add v { succ = Sette.empty; pred = Sette.empty; attrvertex = attrvertex } g.nodes; }

let remove_vertex g v =
  let nodev =
    try node g v
    with Not_found ->
      raise (Failure "FGraph.remove_vertex")
  in
  let nodes = Mappe.remove v g.nodes in
  let nodes =
    Sette.fold
      (begin fun succ nodes ->
	if succ<>v then begin
	  let nsucc = Mappe.find succ nodes in
	  Mappe.add
	    succ
	    { nsucc with pred = Sette.remove v nsucc.pred }
	    nodes
	end
	else
	  nodes
      end)
      nodev.succ
      nodes
  in
  let nodes =
    Sette.fold
      (begin fun pred nodes ->
	if pred<>v then begin
	  let npred = Mappe.find pred nodes in
	  Mappe.add
	    pred
	    { npred with succ = Sette.remove v npred.succ }
	    nodes
	end
	else
	  nodes
      end)
      nodev.pred
      nodes
  in
  let arcs =
    Sette.fold
      (fun succ arcs -> Mappe.remove (v,succ) arcs)
      nodev.succ
      g.arcs;
  in
  let arcs =
    Sette.fold
      (fun pred arcs -> Mappe.remove (pred,v) arcs)
      nodev.pred
      arcs
  in
  {
    nodes = nodes;
    arcs = arcs;
    info = g.info;
  }

(* fonctions auxiliaires *)
let squelette make_attrvertex g =
  Mappe.map
    (fun n -> { n with attrvertex = make_attrvertex() })
    g.nodes

let squelette_multi root make_attrvertex g sroot =
  Mappe.add
    root
    { succ = sroot;
      pred = Sette.empty;
      attrvertex = make_attrvertex() }
    (Mappe.map
       (fun n -> { n with attrvertex = make_attrvertex() })
       g.nodes)

let topological_sort_aux root nodes =
  let rec visit v res =
    let nv = Mappe.find v nodes in
    if !(nv.attrvertex) then
      res
    else
      begin
	nv.attrvertex := true;
	v :: (Sette.fold visit nv.succ res)
      end
  in
  visit root []

let topological_sort g root =
  let nodes = squelette (fun () -> ref false) g in
  topological_sort_aux root nodes

let topological_sort_multi root g sroot =
  let nodes = squelette_multi root  (fun () -> ref false) g sroot in
  List.tl (topological_sort_aux root nodes)


(* retourne les sommets inaccessibles a partir d'un sommet *)
let reachable_aux root nodes g =
  let rec visit v =
    let nv = Mappe.find v nodes in
    if not !(nv.attrvertex) then
      begin
	nv.attrvertex := true;
	Sette.iter visit nv.succ
      end
  in
  visit root ;
  Mappe.fold
    (begin fun v nv removed ->
      if !((Mappe.find v nodes).attrvertex) then
	removed
      else
	Sette.add v removed;
    end)
    g.nodes
    Sette.empty

let reachable g root =
  let nodes = squelette (fun () -> ref false) g in
  reachable_aux root nodes g

let reachable_multi root g sroot =
  let nodes = squelette_multi root (fun () -> ref false) g sroot in
  reachable_aux root nodes g

(* retourne les sommets no coaccessibles a partir d'un sommet *)
let cosquelette make_attrvertex g =
  Mappe.map
    (fun n -> { n with attrvertex = make_attrvertex() })
    g.nodes

let cosquelette_multi root make_attrvertex g sroot =
  Mappe.add
    root
    { pred = sroot;
      succ = Sette.empty;
      attrvertex = make_attrvertex() }
    (Mappe.map
       (fun n -> { n with attrvertex = make_attrvertex() })
       g.nodes)

let coreachable_aux root nodes g =
  let rec visit v =
    let nv = Mappe.find v nodes in
    if not !(nv.attrvertex) then
      begin
	nv.attrvertex := true;
	Sette.iter visit nv.pred
      end
  in
  visit root ;
  Mappe.fold
    (begin fun v nv removed ->
      if !((Mappe.find v nodes).attrvertex) then
	removed
      else
	Sette.add v removed;
    end)
    g.nodes
    Sette.empty

let coreachable g root =
  let nodes = cosquelette (fun () -> ref false) g in
  coreachable_aux root nodes g

let coreachable_multi root g sroot =
  let nodes = cosquelette_multi root (fun () -> ref false) g sroot in
  coreachable_aux root nodes g

(* composantes fortement connexes *)
let cfc_aux root nodes =
  let num       = ref(-1) and
      partition = ref [] and
      pile      = Stack.create()
  in
  let rec visit sommet =
    Stack.push sommet pile;
    let node = (Mappe.find sommet nodes) in
    incr num;
    node.attrvertex := !num;
    let head =
      Sette.fold
	(fun succ head ->
	  let dfn = !((Mappe.find succ nodes).attrvertex) in
	  let m = if dfn=min_int then (visit succ) else dfn in
	  Pervasives.min m head)
	node.succ
	!num
    in
    if head = !(node.attrvertex) then
      begin
	let element = ref (Stack.pop pile) in
	let composante = ref [!element] in
	  (Mappe.find !element nodes).attrvertex := max_int;
	  while !element <> sommet do
	    element := Stack.pop pile;
	    (Mappe.find !element nodes).attrvertex := max_int;
	    composante := !element :: !composante
	  done;
	partition := !composante :: !partition
      end;
    head
  in
  let _ = visit root in
  !partition

let cfc g root =
  let nodes = squelette (fun () -> ref min_int) g in
  cfc_aux root nodes

let cfc_multi root g sroot =
  let nodes = squelette_multi root (fun () -> ref min_int) g sroot in
  match cfc_aux root nodes with
  | [x] :: r when x=root -> r
  | _ -> failwith "graph.ml: cfc_multi"

let scfc_aux root nodes =
  let num       = ref(-1) and
      pile      = Stack.create()
  in
  let rec composante sommet =
    let partition = ref Nil in
    Sette.iter
      (function x ->
	if !((Mappe.find x nodes).attrvertex) = min_int then begin
	  ignore (visit x partition)
	end)
      (Mappe.find sommet nodes).succ;
    Cons(Atome sommet, !partition)

  and visit sommet partition =
    Stack.push sommet pile;
    incr num;
    let node = (Mappe.find sommet nodes) in
    node.attrvertex := !num;
    let head = ref !num and loop = ref false in
    (Sette.iter
       (fun succ ->
	 let dfn = !((Mappe.find succ nodes).attrvertex) in
	 let m =
	   if dfn=min_int
	   then (visit succ partition)
	   else dfn
	 in
	 if m <= !head then begin loop := true; head := m end)
       node.succ);
    if !head = !(node.attrvertex) then
      begin
	node.attrvertex := max_int;
	let element = ref (Stack.pop pile) in
	if !loop then
	  begin
	    while !element <> sommet do
	      (Mappe.find !element nodes).attrvertex := min_int;
	      element := Stack.pop pile
	    done;
	    partition := Cons(List(composante sommet),!partition )
	  end
	else
	  partition := Cons(Atome(sommet),!partition)
      end;
    !head
  in
  let partition = ref Nil in
  let _ = visit root partition in
  !partition

let scfc g root =
  let nodes = squelette (fun () -> ref min_int) g in
  scfc_aux root nodes

let scfc_multi root g sroot =
  let nodes = squelette_multi root (fun () -> ref min_int) g sroot in
  let res = scfc_aux root nodes in
  match res with
  | Cons(Atome(x),l) when x=root -> l
  | _ -> failwith "graph.ml: scfc_multi"

let min g =
  let marks = squelette (fun () -> (ref true)) g in
  Mappe.iter
    (begin fun v nv ->
      Sette.iter
	(fun succ -> let flag = (Mappe.find succ marks).attrvertex in flag := false)
	nv.succ
    end)
    marks;
  Mappe.fold
    (fun v nv res -> if !(nv.attrvertex) then Sette.add v res else res)
    marks
    Sette.empty
let max g =
  Mappe.fold
    (fun sommet node res ->
       if Sette.is_empty node.succ then Sette.add sommet res else res)
    g.nodes
    Sette.empty

let print print_vertex print_attrvertex print_attredge print_info formatter g =
  let print_node formatter node =
    fprintf formatter "@[<hv>attrvertex = %a;@ pred = %a;@ succ = %a;@]"
      print_attrvertex node.attrvertex
      (Sette.print print_vertex) node.pred
      (Sette.print print_vertex) node.succ
  in
  fprintf formatter
    "{ @[<v>nodes = %a;@ arcs = %a;@ info = %a;@] }"
    (Mappe.print
      ~first:"@[<v>" ~last:"@]"
      print_vertex print_node)
    g.nodes
    (Mappe.print
      ~first:"@[<v>" ~last:"@]"
      (fun fmt (x,y) -> fprintf fmt "(%a,%a)" print_vertex x print_vertex y)
      print_attredge)
    g.arcs
    print_info g.info
  ;
  ()

let print_dot
  ?(titlestyle:string="shape=ellipse,style=bold,style=filled,fontsize=20")
  ?(vertexstyle:string="shape=ellipse,fontsize=12")
  ?(edgestyle:string="fontsize=12")
  ?(title:string="")
  print_vertex print_attrvertex print_attredge
  fmt g
  =
  fprintf fmt "digraph G {@.  @[<v>";
  if title<>"" then
    fprintf fmt "1073741823 [%s,label=\"%s\"];@ " titlestyle title;
  Mappe.iter
    (begin fun vertex node ->
      fprintf fmt "%a [%s,label=\"%t\"];@ "
      print_vertex vertex
      vertexstyle
      (fun fmt -> print_attrvertex fmt vertex node.attrvertex);
    end)
    g.nodes;
  Mappe.iter
    (begin fun ((pred,succ) as edge) attredge ->
      fprintf fmt "%a -> %a [%s,label=\"%t\"];@ "
      print_vertex pred print_vertex succ
      edgestyle
      (fun fmt -> print_attredge fmt edge attredge);
    end)
    g.arcs;
  fprintf fmt "@]@.}@.";
  ()

let repr x = x
let obj x = x

(*  ********************************************************************** *)
(** {2 Functor version} *)
(*  ********************************************************************** *)

module type T = sig
  module MapV : Mappe.S
    (** Map module for associating attributes to vertices, of type [MapV.key]
      *)
  module MapE : (Mappe.S with type key = MapV.key * MapV.key)
    (** Map module for associating attributes to edges, of type [MapV.key *
      MapV.key] *)
end

module type S = sig
  type vertex
    (** The type of vertices *)
  module SetV : (Sette.S with type elt=vertex)
    (** The type of sets of vertices *)
  module SetE : (Sette.S with type elt=vertex*vertex)
    (** The type of sets of edges *)
  module MapV : (Mappe.S with type key=vertex and module Setkey=SetV)
    (** The Map for vertices *)
  module MapE : (Mappe.S with type key=vertex*vertex and module Setkey=SetE)
    (** The Map for edges *)

  type ('b,'c,'d) t
    (** The type of graphs, where:
      - ['b] is the type of vertex attribute (attrvertex);
      - ['c] is the type of edge attributes (attredge)
    *)

  val info : ('b,'c,'d) t -> 'd
  val set_info : ('b,'c,'d) t -> 'd -> ('b,'c,'d) t
  val succ : ('b,'c,'d) t -> vertex -> SetV.t
  val pred : ('b,'c,'d) t -> vertex -> SetV.t
  val attrvertex : ('b,'c,'d) t -> vertex -> 'b
  val attredge : ('b,'c,'d) t -> vertex * vertex -> 'c
  val empty : 'd -> ('b,'c,'d) t
  val size_vertex : ('b,'c,'d) t -> int
  val size_edge : ('b,'c,'d) t -> int
  val size : ('b,'c,'d) t -> int*int
  val is_empty : ('b,'c,'d) t -> bool
  val is_vertex : ('b,'c,'d) t -> vertex -> bool
  val is_edge : ('b,'c,'d) t -> vertex * vertex -> bool
  val vertices : ('b,'c,'d) t -> SetV.t
  val edges : ('b,'c,'d) t -> SetE.t

  val map_vertex : ('b,'c,'d) t -> (vertex -> 'b -> pred:SetV.t -> succ:SetV.t -> 'e) -> ('e, 'c,'d) t
  val map_edge : ('b,'c,'d) t -> (vertex * vertex -> 'c -> 'e) -> ('b, 'e, 'd) t
  val map_info : ('b,'c,'d) t -> ('d -> 'e) -> ('b,'c,'e) t
  val map :
    ('b,'c,'d) t ->
    (vertex -> 'b -> pred:SetV.t -> succ:SetV.t -> 'bb) ->
    (vertex * vertex -> 'c -> 'cc) ->
    ('d -> 'dd) ->
    ('bb,'cc,'dd) t
  val transpose :
    ('b,'c,'d) t ->
    (vertex -> 'b -> pred:SetV.t -> succ:SetV.t -> 'bb) ->
    (vertex * vertex -> 'c -> 'cc) ->
    ('d -> 'dd) ->
    ('bb,'cc,'dd) t
  val iter_vertex : ('b,'c,'d) t -> (vertex -> 'b -> pred:SetV.t -> succ:SetV.t -> unit) -> unit
  val iter_edge : ('b,'c,'d) t -> ((vertex * vertex) -> 'c -> unit) -> unit
  val fold_vertex : ('b,'c,'d) t -> 'e -> (vertex -> 'b -> pred:SetV.t -> succ:SetV.t -> 'e -> 'e) -> 'e
  val fold_edge : ('b,'c,'d) t -> 'e -> (vertex * vertex -> 'c -> 'e -> 'e) -> 'e

  val add_edge : ('b,'c,'d) t -> vertex * vertex -> 'c -> ('b,'c,'d) t
  val remove_edge : ('b,'c,'d) t -> vertex * vertex -> ('b,'c,'d) t
  val add_vertex : ('b,'c,'d) t -> vertex -> 'b -> ('b,'c,'d) t
  val remove_vertex : ('b,'c,'d) t -> vertex -> ('b,'c,'d) t
  val topological_sort : ('b,'c,'d) t -> vertex -> vertex list
  val topological_sort_multi : vertex -> ('b,'c,'d) t -> SetV.t -> vertex list
  val reachable : ('b,'c,'d) t -> vertex -> SetV.t
  val reachable_multi :
  vertex -> ('b,'c,'d) t -> SetV.t -> SetV.t
  val coreachable : ('b,'c,'d) t -> vertex -> SetV.t
  val coreachable_multi :
  vertex -> ('b,'c,'d) t -> SetV.t -> SetV.t
  val cfc : ('b,'c,'d) t -> vertex -> vertex list list
  val cfc_multi : vertex -> ('b,'c,'d) t -> SetV.t -> vertex list list
  val scfc : ('b,'c,'d) t -> vertex -> vertex Ilist.t
  val scfc_multi : vertex -> ('b,'c,'d) t -> SetV.t -> vertex Ilist.t
  val min : ('b,'c,'d) t -> SetV.t
  val max : ('b,'c,'d) t -> SetV.t
  val print :
    (Format.formatter -> vertex -> unit) ->
    (Format.formatter -> 'b -> unit) ->
    (Format.formatter -> 'c -> unit) ->
    (Format.formatter -> 'd -> unit) ->
    Format.formatter -> ('b,'c,'d) t -> unit
  val print_dot :
    ?titlestyle:string ->
    ?vertexstyle:string ->
    ?edgestyle:string ->
    ?title:string ->
    (Format.formatter -> vertex -> unit) ->
    (Format.formatter -> vertex -> 'b -> unit) ->
    (Format.formatter -> vertex*vertex -> 'c -> unit) ->
    Format.formatter -> ('b,'c,'d) t -> unit

  val repr : ('b,'c,'d) t -> (vertex,'b,'c,'d) graph
  val obj : (vertex,'b,'c,'d) graph -> ('b,'c,'d) t
end

module Make(T : T) : (S with type vertex=T.MapV.key
			and module SetV=T.MapV.Setkey
			and module SetE=T.MapE.Setkey
			and module MapV=T.MapV
			and module MapE=T.MapE)
  =
struct

  type vertex = T.MapV.key
  module SetV = T.MapV.Setkey
  module SetE = T.MapE.Setkey
  module MapV = T.MapV
  module MapE = T.MapE

  type 'b node = {
    succ: SetV.t;
    pred: SetV.t;
    attrvertex: 'b
  }
  type ('b,'c,'d) t = {
    nodes: 'b node MapV.t;
    arcs: 'c MapE.t;
    info : 'd;
  }

  let info g = g.info
  let set_info g info = { g with info=info }
  let node g n = MapV.find n g.nodes
  let succ g n = (node g n).succ
  let pred g n = (node g n).pred
  let attrvertex g n = (node g n).attrvertex

  let attredge g arc = MapE.find arc g.arcs
  let empty info = { nodes = MapV.empty; arcs = MapE.empty; info = info }
  let size_vertex g = MapV.cardinal g.nodes
  let size_edge g = MapE.cardinal g.arcs
  let size g = (size_vertex g, size_edge g)

  let is_empty g = (g.nodes = MapV.empty)
  let is_vertex g i =
    try let _ = node g i in true
    with Not_found -> false
  let is_edge g arc =
    try let _ = MapE.find arc g.arcs in true
    with Not_found -> false

  let vertices g = MapV.maptoset g.nodes
  let edges g = MapE.maptoset g.arcs

  let map_vertex g f = { g with
    nodes =
    MapV.mapi
      (fun v nv -> { nv with attrvertex = f v nv.attrvertex ~pred:nv.pred ~succ:nv.succ })
      g.nodes;
  }

  let iter_vertex g f = MapV.iter (fun v nv -> f v nv.attrvertex ~pred:nv.pred ~succ:nv.succ) g.nodes
  let fold_vertex g r f = MapV.fold (fun v nv r -> f v nv.attrvertex ~pred:nv.pred ~succ:nv.succ r) g.nodes r
  let map_edge g f = { g with
    arcs = MapE.mapi f g.arcs
  }
  let iter_edge g f = MapE.iter f g.arcs
  let fold_edge g r f = MapE.fold f g.arcs r

  let map_info g f = { g with
    info = f g.info
  }

  let map g mapvertex mapedge mapinfo = {
    nodes = MapV.mapi
    (fun v node -> { node with
      attrvertex = mapvertex v node.attrvertex ~pred:node.pred ~succ:node.succ;
    })
    g.nodes;
    arcs = MapE.mapi mapedge g.arcs;
    info = mapinfo g.info;
  }

  let transpose g mapvertex mapedge mapinfo = {
    nodes = MapV.mapi
    (fun v node -> {
      succ = node.pred;
      pred = node.succ;
      attrvertex = mapvertex v node.attrvertex ~pred:node.pred ~succ:node.succ;
    })
    g.nodes;
    arcs = MapE.fold
    (begin fun ((x,y) as xy) attredge res ->
      MapE.add (y,x) (mapedge xy attredge) res
    end)
    g.arcs MapE.empty;
    info = mapinfo g.info;
  }

  let add_edge g ((a,b) as arc) attredge =
    try {
      nodes = begin
	if is_edge g arc then
	  g.nodes
	else
	  let na = node g a in
	  if a=b then
	    MapV.add a
	      { succ = SetV.add a na.succ; pred = SetV.add b na.pred; attrvertex = na.attrvertex }
	      g.nodes
	  else
	    let nb = node g b in
	    MapV.add a
	      { succ = SetV.add b na.succ; pred = na.pred; attrvertex = na.attrvertex }
	      (MapV.add b
		{ succ = nb.succ; pred = SetV.add a nb.pred; attrvertex = nb.attrvertex }
		g.nodes)
      end;
      arcs = MapE.add arc attredge g.arcs;
      info = g.info;
    }
    with Not_found -> failwith "FGraph.add_edge"

  let remove_edge g ((a,b) as arc) =
    if MapE.mem arc g.arcs then
      try {
	nodes = begin
	  let na = node g a in
	  if a=b then
	    MapV.add a
	      { succ = SetV.remove a na.succ; pred = SetV.remove a na.pred; attrvertex = na.attrvertex }
	      g.nodes
	  else
	    let nb = node g b in
	    MapV.add a
	      { succ = SetV.remove b na.succ; pred = na.pred; attrvertex = na.attrvertex }
	      (MapV.add b
		{ succ = nb.succ; pred = SetV.remove a nb.pred; attrvertex = nb.attrvertex }
		g.nodes)
	end;
	arcs = MapE.remove arc g.arcs;
	info = g.info;
      }
      with Not_found -> failwith "FGraph.remove_edge"
    else
      g

  let add_vertex g v attrvertex =
    try
      let anode = MapV.find v g.nodes in
      { g with nodes = MapV.add v { anode with attrvertex = attrvertex } g.nodes;}
    with Not_found ->
      { g with nodes = MapV.add v { succ = SetV.empty; pred = SetV.empty; attrvertex = attrvertex } g.nodes; }

  let remove_vertex g v =
    let nodev =
      try node g v
      with Not_found ->
	raise (Failure "FGraph.remove_vertex")
    in
    let nodes = MapV.remove v g.nodes in
    let nodes =
      SetV.fold
	(begin fun succ nodes ->
	  if (SetV.Ord.compare succ v) <> 0 then begin
	    let nsucc = MapV.find succ nodes in
	    MapV.add
	      succ
	      { nsucc with pred = SetV.remove v nsucc.pred }
	      nodes
	  end
	  else
	    nodes
	end)
	nodev.succ
	nodes
    in
    let nodes =
      SetV.fold
	(begin fun pred nodes ->
	  if (SetV.Ord.compare pred v) <> 0 then begin
	    let npred = MapV.find pred nodes in
	    MapV.add
	      pred
	      { npred with succ = SetV.remove v npred.succ }
	      nodes
	  end
	  else
	    nodes
	end)
	nodev.pred
	nodes
    in
    let arcs =
      SetV.fold
	(fun succ arcs -> MapE.remove (v,succ) arcs)
	nodev.succ
	g.arcs;
    in
    let arcs =
      SetV.fold
	(fun pred arcs -> MapE.remove (pred,v) arcs)
	nodev.pred
	arcs
    in
    {
      nodes = nodes;
      arcs = arcs;
      info = g.info;
    }

  (* fonctions auxiliaires *)
  let squelette make_attrvertex g =
    MapV.map
      (fun n -> { n with attrvertex = make_attrvertex() })
      g.nodes

  let squelette_multi root make_attrvertex g sroot =
    MapV.add
      root
      { succ = sroot;
      pred = SetV.empty;
      attrvertex = make_attrvertex() }
      (MapV.map
	(fun n -> { n with attrvertex = make_attrvertex() })
	g.nodes)

  let topological_sort_aux root nodes =
    let rec visit v res =
      let nv = MapV.find v nodes in
      if !(nv.attrvertex) then
	res
      else
	begin
	nv.attrvertex := true;
	v :: (SetV.fold visit nv.succ res)
	end
    in
    visit root []

  let topological_sort g root =
    let nodes = squelette (fun () -> ref false) g in
    topological_sort_aux root nodes

  let topological_sort_multi root g sroot =
    let nodes = squelette_multi root  (fun () -> ref false) g sroot in
    List.tl (topological_sort_aux root nodes)

  (* retourne les sommets inaccessibles a partir d'un sommet *)
  let reachable_aux root nodes g =
    let rec visit v =
      let nv = MapV.find v nodes in
      if not !(nv.attrvertex) then
	begin
	nv.attrvertex := true;
	SetV.iter visit nv.succ
	end
    in
    visit root ;
    MapV.fold
      (begin fun v nv removed ->
	if !((MapV.find v nodes).attrvertex) then
	removed
	else
	SetV.add v removed;
      end)
      g.nodes
      SetV.empty

  let reachable g root =
    let nodes = squelette (fun () -> ref false) g in
    reachable_aux root nodes g

  let reachable_multi root g sroot =
    let nodes = squelette_multi root (fun () -> ref false) g sroot in
    reachable_aux root nodes g

  (* retourne les sommets non coaccessibles a partir d'un sommet *)
  let cosquelette make_attrvertex g =
    MapV.map
      (fun n -> { n with attrvertex = make_attrvertex() })
      g.nodes

  let cosquelette_multi root make_attrvertex g sroot =
    MapV.add
      root
      { pred = sroot;
      succ = SetV.empty;
      attrvertex = make_attrvertex() }
      (MapV.map
	(fun n -> { n with attrvertex = make_attrvertex() })
	g.nodes)

  let coreachable_aux root nodes g =
    let rec visit v =
      let nv = MapV.find v nodes in
      if not !(nv.attrvertex) then
	begin
	nv.attrvertex := true;
	SetV.iter visit nv.pred
	end
    in
    visit root ;
    MapV.fold
      (begin fun v nv removed ->
	if !((MapV.find v nodes).attrvertex) then
	removed
	else
	SetV.add v removed;
      end)
      g.nodes
      SetV.empty

  let coreachable g root =
    let nodes = cosquelette (fun () -> ref false) g in
    coreachable_aux root nodes g

  let coreachable_multi root g sroot =
    let nodes = cosquelette_multi root (fun () -> ref false) g sroot in
    coreachable_aux root nodes g

  (* composantes fortement connexes *)
  let cfc_aux root nodes =
    let num       = ref(-1) and
	partition = ref [] and
	pile      = Stack.create()
    in
    let rec visit sommet =
      Stack.push sommet pile;
      let node = (MapV.find sommet nodes) in
      incr num;
      node.attrvertex := !num;
      let head =
	SetV.fold
	(fun succ head ->
	  let dfn = !((MapV.find succ nodes).attrvertex) in
	  let m = if dfn=min_int then (visit succ) else dfn in
	  Pervasives.min m head)
	node.succ
	!num
      in
      if head = !(node.attrvertex) then
	begin
	let element = ref (Stack.pop pile) in
	let composante = ref [!element] in
	  (MapV.find !element nodes).attrvertex := max_int;
	  while !element <> sommet do
	    element := Stack.pop pile;
	    (MapV.find !element nodes).attrvertex := max_int;
	    composante := !element :: !composante
	  done;
	partition := !composante :: !partition
	end;
      head
    in
    let _ = visit root in
    !partition

  let cfc g root =
    let nodes = squelette (fun () -> ref min_int) g in
    cfc_aux root nodes

  let cfc_multi root g sroot =
    let nodes = squelette_multi root (fun () -> ref min_int) g sroot in
    match cfc_aux root nodes with
    | [x] :: r when (SetV.Ord.compare x root)=0 -> r
    | _ -> failwith "graph.ml: cfc_multi"

  let scfc_aux root nodes =
    let num       = ref(-1) and
	pile      = Stack.create()
    in
    let rec composante sommet =
      let partition = ref Nil in
      SetV.iter
	(function x ->
	if !((MapV.find x nodes).attrvertex) = min_int then begin
	  ignore (visit x partition)
	end)
	(MapV.find sommet nodes).succ;
      Cons(Atome sommet, !partition)

    and visit sommet partition =
      Stack.push sommet pile;
      incr num;
      let node = (MapV.find sommet nodes) in
      node.attrvertex := !num;
      let head = ref !num and loop = ref false in
      (SetV.iter
	 (fun succ ->
	 let dfn = !((MapV.find succ nodes).attrvertex) in
	 let m =
	   if dfn=min_int
	   then (visit succ partition)
	   else dfn
	 in
	 if m <= !head then begin loop := true; head := m end)
	 node.succ);
      if !head = !(node.attrvertex) then
	begin
	node.attrvertex := max_int;
	let element = ref (Stack.pop pile) in
	if !loop then
	  begin
	    while !element <> sommet do
	      (MapV.find !element nodes).attrvertex := min_int;
	      element := Stack.pop pile
	    done;
	    partition := Cons(List(composante sommet),!partition )
	  end
	else
	  partition := Cons(Atome(sommet),!partition)
	end;
      !head
    in
    let partition = ref Nil in
    let _ = visit root partition in
    !partition

  let scfc g root =
    let nodes = squelette (fun () -> ref min_int) g in
    scfc_aux root nodes

  let scfc_multi root g sroot =
    let nodes = squelette_multi root (fun () -> ref min_int) g sroot in
    let res = scfc_aux root nodes in
    match res with
    | Cons(Atome(x),l) when (SetV.Ord.compare x root)=0 -> l
    | _ -> failwith "graph.ml: scfc_multi"

  let min g =
    let marks = squelette (fun () -> (ref true)) g in
    MapV.iter
      (begin fun v nv ->
	SetV.iter
	(fun succ -> let flag = (MapV.find succ marks).attrvertex in flag := false)
	nv.succ
      end)
      marks;
    MapV.fold
      (fun v nv res -> if !(nv.attrvertex) then SetV.add v res else res)
      marks
      SetV.empty
  let max g =
    MapV.fold
      (fun sommet node res ->
	if SetV.is_empty node.succ then SetV.add sommet res else res)
      g.nodes
      SetV.empty

  let print print_vertex print_attrvertex print_attredge print_info formatter g =
    let print_node formatter node =
      fprintf formatter "@[<hv>attrvertex = %a;@ pred = %a;@ succ = %a;@]"
	print_attrvertex node.attrvertex
	(SetV.print print_vertex) node.pred
	(SetV.print print_vertex) node.succ
    in
    fprintf formatter
      "{ @[<v>nodes = %a;@ arcs = %a;@ info = %a;@] }"
      (MapV.print
	~first:"@[<v>" ~last:"@]"
	print_vertex print_node)
      g.nodes
      (MapE.print
	~first:"@[<v>" ~last:"@]"
	(fun fmt (x,y) -> fprintf fmt "(%a,%a)" print_vertex x print_vertex y)
	print_attredge)
      g.arcs
      print_info g.info
    ;
    ()

  let print_dot
    ?(titlestyle:string="shape=ellipse,style=bold,style=filled,fontsize=20")
    ?(vertexstyle:string="shape=ellipse,fontsize=12")
    ?(edgestyle:string="fontsize=12")
    ?(title:string="")
    print_vertex print_attrvertex print_attredge
    fmt g
    =
    fprintf fmt "digraph G {@.  @[<v>";
    if title<>"" then
      fprintf fmt "1073741823 [%s,label=\"%s\"];@ " titlestyle title;
    MapV.iter
      (begin fun vertex node ->
	fprintf fmt "%a [%s,label=\"%t\"];@ "
	print_vertex vertex
	vertexstyle
	(fun fmt -> print_attrvertex fmt vertex node.attrvertex);
      end)
      g.nodes;
    MapE.iter
      (begin fun ((pred,succ) as edge) attredge ->
	fprintf fmt "%a -> %a [%s,label=\"%t\"];@ "
	print_vertex pred print_vertex succ
	edgestyle
	(fun fmt -> print_attredge fmt edge attredge);
      end)
      g.arcs;
    fprintf fmt "@]@.}@.";
    ()

  let repr = Obj.magic
  let obj = Obj.magic
end
