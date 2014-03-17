(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Use ocp-index to fill out the completion and object-info messages
 *
 *)

val init : unit -> LibIndex.t
val complete : LibIndex.t -> Ipython_json_t.complete_request -> Ipython_json_t.complete_reply
val info : LibIndex.t -> Ipython_json_t.object_info_request -> Ipython_json_t.object_info_reply

