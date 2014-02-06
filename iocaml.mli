open Ipython_json_t

module Shell : sig
    type iopub_message = 
        | Iopub_set_current of Message.message
        | Iopub_send_message of Message.message_content
        | Iopub_suppress_stdout of bool
        | Iopub_suppress_stderr of bool
        | Iopub_flush
        | Iopub_send_mime of string * bool
        | Iopub_stop
end

val connection_info : connection_info

(* suppress output *)
val suppress_stdout : bool -> unit
val suppress_stderr : bool -> unit
val suppress_compiler : bool -> unit
val suppress_all : bool -> unit

(* low level messaging *)
val send_iopub : Shell.iopub_message -> unit
val send_message : Message.message_content -> unit
val send_flush : unit -> unit

(* mime display *)
val display : ?base64:bool -> string -> string -> unit
val mime : out_channel
val send_mime : ?base64:bool -> string -> unit

val main : unit -> unit

