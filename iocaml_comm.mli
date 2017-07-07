(*
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Top level loop, socket communications amd user API
 *
 *)

type t =
  {
    target_name : string;
    on_open : Ipython_json_t.comm_data -> unit;
    on_msg : Ipython_json_t.comm_data -> unit;
    on_close : Ipython_json_t.comm_data -> unit;
  }

val register_target :
  ?on_open:(Ipython_json_t.comm_data -> unit) ->
  ?on_msg:(Ipython_json_t.comm_data -> unit) ->
  ?on_close:(Ipython_json_t.comm_data -> unit) ->
  string -> unit

val unregister_target : string -> unit

val comm_open : Ipython_json_t.comm_data -> unit

val comm_msg : Ipython_json_t.comm_data -> unit

val comm_close : Ipython_json_t.comm_data -> unit
