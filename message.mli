(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: IPython messages
 *
 *)

open Ipython_json_t
open Iocaml_zmq

type message_content = 
    (* messages received from front end *)
    | Connect_request
    | Kernel_info_request
    | Shutdown_request of shutdown
    | Execute_request of execute_request
    | Inspect_Request of inspect_request
    | Complete_request of complete_request
    | History_request of history_request
    (* messages sent to front end *)
    | Connect_reply of connect_reply
    | Kernel_info_reply of kernel_info_reply
    | Shutdown_reply of shutdown
    | Execute_reply of execute_reply
    | Inspect_reply of inspect_reply
    | Complete_reply of complete_reply
    | History_reply of history_reply
    (* other *)
    | Status of status
    | Execute_input of execute_input
    | Execute_result of execute_result
    | Stream of stream
    | Clear of clear_output
    | Display_data of display_data
    (* custom messages *)
    | Comm_open

val content_of_json : header_info -> string -> message_content
val json_of_content : message_content -> string
val msg_type_of_content : message_content -> string

type message = 
    {
        ids : string array;
        hmac : string;
        header : header_info;
        parent : header_info;
        meta : string; (* XXX dict => assoc list I think *)
        content : message_content; 
        raw : string array;
    }

val log : message -> unit

val recv : [`Router] ZMQ.Socket.t -> message
val send : [<`Router|`Pub] ZMQ.Socket.t -> message -> unit
val make_header : message -> message
val send_h : [<`Router|`Pub] ZMQ.Socket.t -> message -> message_content -> unit

