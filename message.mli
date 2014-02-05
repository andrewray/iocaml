open Ipython_json_t

type message_content = 
    (* messages received from front end *)
    | Connect_request
    | Kernel_info_request
    | Shutdown_request of shutdown
    | Execute_request of execute_request
    (* messages sent to front end *)
    | Connect_reply of connect_reply
    | Kernel_info_reply of kernel_info_reply
    | Shutdown_reply of shutdown
    | Execute_reply of execute_reply
    | Status of status
    | Pyin of pyin
    | Stream of stream
    | Display_data of display_data

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
        content : message_content; (* XXX message data based on type *)
        raw : string array;
    }

val log : message -> unit

val recv : [`Router] ZMQ.Socket.t -> message
val send : [<`Router|`Pub] ZMQ.Socket.t -> message -> unit
val make_header : message -> message
val send_h : [<`Router|`Pub] ZMQ.Socket.t -> message -> message_content -> unit

