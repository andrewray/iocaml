(* simple tab completion API *)

val init : unit -> LibIndex.t
val complete : LibIndex.t -> Ipython_json_t.complete_request -> Ipython_json_t.complete_reply
val info : LibIndex.t -> Ipython_json_t.object_info_request -> Ipython_json_t.object_info_reply

