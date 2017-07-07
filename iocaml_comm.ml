(*
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Top level loop, socket communications amd user API
 *
 *)

open Format
open Ipython_json_t

type t =
  {
    target_name : string;
    on_open : Ipython_json_t.comm_data -> unit;
    on_msg : Ipython_json_t.comm_data -> unit;
    on_close : Ipython_json_t.comm_data -> unit;
  }

let target_tbl = Hashtbl.create 16
let comm_tbl = Hashtbl.create 16

let register_target ?(on_open = ignore) ?(on_msg = ignore) ?(on_close = ignore) name =
  let comm = { target_name = name; on_open; on_msg; on_close; } in
  Hashtbl.replace target_tbl name comm

let unregister_target name =
  Hashtbl.remove target_tbl name

let comm_open req =
  match req.cd_target_name with
  | None -> eprintf "[ERROR] comm_open requires field \"target_name\"\n%!"
  | Some target_name ->
    try
      let comm = Hashtbl.find target_tbl target_name in
      Hashtbl.replace comm_tbl req.cd_comm_id comm ;
      comm.on_open req
    with Not_found ->
      eprintf "[ERROR] No such comm target %S\n%!" target_name

let comm_close req =
  try
    let comm = Hashtbl.find comm_tbl req.cd_comm_id in
    comm.on_close req ;
    Hashtbl.remove comm_tbl req.cd_comm_id
  with Not_found ->
    eprintf "[ERROR] No such comm_id %S\n%!" req.cd_comm_id

let comm_msg req =
  try
    let comm = Hashtbl.find comm_tbl req.cd_comm_id in
    comm.on_msg req
  with Not_found ->
    eprintf "[ERROR] No such comm_id %S\n%!" req.cd_comm_id
