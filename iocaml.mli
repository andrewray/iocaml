(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Top level loop, socket communications and user API.
 *
 *)

open Ipython_json_t

module Shell : sig
    (** messages that can be sent to the iopub socket 
        and potentially on to the front end *)
    type iopub_message =
        (** set the current execution context *) 
        | Iopub_set_current of Message.message
        (** send iopub message *)
        | Iopub_send_message of Message.message_content
        (** enable/disable stdout messages *)
        | Iopub_suppress_stdout of bool
        (** enable/disable stderr messages *)
        | Iopub_suppress_stderr of bool
        (** flush stdout/stderr *)
        | Iopub_flush
        (** send a mime message *)
        | Iopub_send_mime of string * bool
        (** halt iopub thread *)
        | Iopub_stop
end

(** connection information *)
val connection_info : connection_info

(** suppress stdout *)
val suppress_stdout : bool -> unit

(** suppress stderr *)
val suppress_stderr : bool -> unit

(** suppress compiler output *)
val suppress_compiler : bool -> unit

(** suppress all output (except mime messages) *)
val suppress_all : bool -> unit

(** ocp-index *)
val index : LibIndex.t

(** send message to iopub thread *)
val send_iopub : Shell.iopub_message -> unit

(** send message over iopub socket *)
val send_message : Message.message_content -> unit

(** flush stdout/stderr *)
val send_flush : unit -> unit

(* mime display *)

(** display ~base64 mime_type data sends data to the frontend as the given
    mime type with optional base64 encoding. *)
val display : ?base64:bool -> string -> string -> unit

(** channel to which the data for a mime message can be written *)
val mime : out_channel

(** sends the message (once it's been written to the mime channel) with
    the given mime type and option base64 encoding *)
val send_mime : ?base64:bool -> string -> unit

(** DONT USE!!! *)
val main : unit -> unit

