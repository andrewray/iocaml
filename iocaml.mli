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
        (** send raw iopub message *)
        | Iopub_send_raw_message of Message.message
        (** enable/disable stdout messages *)
        | Iopub_suppress_stdout of bool
        (** enable/disable stderr messages *)
        | Iopub_suppress_stderr of bool
        (** flush stdout/stderr *)
        | Iopub_flush
        (** send a mime message *)
        | Iopub_send_mime of Message.message option * string * bool
        (** get current message context *)
        | Iopub_get_current
        (** halt iopub thread *)
        | Iopub_stop

    type iopub_resp = 
        | Iopub_ok
        | Iopub_context of Message.message option
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

val index : Iocaml_complete.index

type cell_context

(** css value for max-height property used for compiler messages *)
val output_cell_max_height : string ref

(** send message to iopub thread *)
val send_iopub : Shell.iopub_message -> Shell.iopub_resp

(** send message over iopub socket *)
val send_message : ?context:cell_context -> Message.message_content -> unit

(** flush stdout/stderr *)
val send_flush : unit -> unit

(* mime display *)

(** base 64 encode *)
val base64enc : string -> string

(** create a data uri string (default is to base64 encode the data) *)
val data_uri : ?base64:bool -> string -> string -> string

(** display ~base64 mime_type data sends data to the frontend as the given
    mime type with optional base64 encoding. *)
val display : ?context:cell_context -> ?base64:bool -> string -> string -> unit

(** channel to which the data for a mime messages can be written *)
val mime : out_channel

(** sends the message (once it's been written to the mime channel) with
    the given mime type and option base64 encoding *)
val send_mime : ?context:cell_context -> ?base64:bool -> string -> unit

(** sends message to clear cell output area (requires IPython 2.0+) *)
val send_clear : ?context:cell_context -> 
    ?wait:bool -> ?stdout:bool -> ?stderr:bool -> ?other:bool -> unit -> unit

(* get current cells context *)
val cell_context : unit -> cell_context

(** DONT USE!!! *)
val main : unit -> unit

