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
open Ipython_json_j

type message_content = 
    (* messages received from front end *)
    | Connect_request
    | Kernel_info_request
    | Shutdown_request of shutdown
    | Execute_request of execute_request
    | Object_info_request of object_info_request
    | Complete_request of complete_request
    | History_request of history_request
    (* messages sent to front end *)
    | Connect_reply of connect_reply
    | Kernel_info_reply of kernel_info_reply
    | Shutdown_reply of shutdown
    | Execute_reply of execute_reply
    | Object_info_reply of object_info_reply
    | Complete_reply of complete_reply
    | History_reply of history_reply
    (* others *)
    | Status of status
    | Pyin of pyin
    | Pyout of pyout
    | Stream of stream
    | Display_data of display_data

let content_of_json hdr c = 
    match hdr.msg_type with
    | "connect_request" -> Connect_request
    | "kernel_info_request" -> Kernel_info_request
    | "shutdown_request" -> Shutdown_request(shutdown_of_string c)
    | "execute_request" -> Execute_request(execute_request_of_string c)
    | "object_info_request" -> Object_info_request(object_info_request_of_string c)
    | "complete_request" -> Complete_request(complete_request_of_string c)
    | "history_request" -> History_request(history_request_of_string c)

    | "connect_reply" -> Connect_reply(connect_reply_of_string c)
    | "kernel_info_reply" -> Kernel_info_reply(kernel_info_reply_of_string c)
    | "shutdown_reply" -> Shutdown_reply(shutdown_of_string c)
    | "execute_reply" -> Execute_reply(execute_reply_of_string c)
    | "object_info_reply" -> Object_info_reply(object_info_reply_of_string c)
    | "complete_reply" -> Complete_reply(complete_reply_of_string c)
    | "history_reply" -> History_reply(history_reply_of_string c)

    | "status" -> Status(status_of_string c)
    | "pyin" -> Pyin(pyin_of_string c)
    | "pyout" -> Pyout(pyout_of_string c)
    | "stream" -> Stream(stream_of_string c)
    | "display_data" -> Display_data(display_data_of_string c)
    | _ -> failwith ("content_of_json: " ^ hdr.msg_type)

let json_of_content = function
    | Connect_request -> "{}"
    | Kernel_info_request -> "{}"
    | Shutdown_request(x) -> string_of_shutdown x
    | Execute_request(x) -> string_of_execute_request x
    | Object_info_request(x) -> string_of_object_info_request x
    | Complete_request(x) -> string_of_complete_request x
    | History_request(x) -> string_of_history_request x

    | Connect_reply(x) -> string_of_connect_reply x
    | Kernel_info_reply(x) -> string_of_kernel_info_reply x
    | Shutdown_reply(x) -> string_of_shutdown x
    | Execute_reply(x) -> string_of_execute_reply x
    | Object_info_reply(x) -> string_of_object_info_reply x
    | Complete_reply(x) -> string_of_complete_reply x
    | History_reply(x) -> string_of_history_reply x

    | Status(x) -> string_of_status x
    | Pyin(x) -> string_of_pyin x
    | Pyout(x) -> string_of_pyout x
    | Stream(x) -> string_of_stream x
    | Display_data(x) -> string_of_display_data x

let msg_type_of_content = function
    | Connect_request -> "connect_request"
    | Kernel_info_request -> "kernel_info_request"
    | Shutdown_request(_) -> "shutdown_request"
    | Execute_request(_) -> "execute_request"
    | Object_info_request(_) -> "object_info_request"
    | Complete_request(_) -> "complete_request"
    | History_request(_) -> "history_request"

    | Connect_reply(_) -> "connect_reply"
    | Kernel_info_reply(_) -> "kernel_info_reply"
    | Shutdown_reply(_) -> "shutdown_reply"
    | Execute_reply(_) -> "execute_reply"
    | Object_info_reply(_) -> "object_info_reply"
    | Complete_reply(_) -> "complete_reply"
    | History_reply(_) -> "history_reply"

    | Status(_) -> "status"
    | Pyin(_) -> "pyin"
    | Pyout(_) -> "pyout"
    | Stream(_) -> "stream"
    | Display_data(_) -> "display_data"

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

let log msg = 
    let open Printf in
    Array.iter (fun id -> Log.log(id ^ "\n")) msg.ids;
    Log.log ("<IDS|MSG>\n");
    Log.log (sprintf "  HMAC: %s\n" msg.hmac);
    Log.log (sprintf "  header: %s\n" (string_of_header_info msg.header));
    Log.log (sprintf "  parent: %s\n" (string_of_header_info msg.parent));
    Log.log (sprintf "  content: %s\n" (json_of_content msg.content))
    
let recv socket = 
    let msg = ZMQ.Socket.recv_all socket in
    let rec split ids = function
        | [] -> failwith "couldn't find <IDS|MSG> marker"
        | "<IDS|MSG>" :: t -> Array.of_list (List.rev ids), Array.of_list t
        | h :: t -> split (h::ids) t
    in
    let ids, data = split [] msg in
    let len = Array.length data in
    let header = header_info_of_string data.(1) in
    assert (len >= 5);
    (*let () = Log.log ("RECV:\n" ^ data.(4) ^ "\n") in*)
    let msg = 
        {
            ids = ids;
            hmac = data.(0);
            header = header;
            parent = header_info_of_string data.(2);
            meta = data.(3);
            content = content_of_json header data.(4);
            raw = Array.init (len-5) (fun i -> data.(i+5))
        }
    in
    let () = log msg in
    msg

let send socket msg =
    let () = Log.log ("SEND\n") in
    let () = log msg in
    let content = json_of_content msg.content in
    ZMQ.Socket.send_all socket (List.concat [
        Array.to_list msg.ids;
        ["<IDS|MSG>"];
        [msg.hmac];
        [string_of_header_info msg.header];
        [string_of_header_info msg.parent];
        [msg.meta];
        [content];
        Array.to_list msg.raw;
    ])

let make_header msg = 
    { msg with
        header = { msg.header with
                        msg_type = msg_type_of_content msg.content;
                        msg_id = Uuidm.(to_string (create `V4)) };
        parent = msg.header
    }

let send_h socket msg content = 
    send socket (make_header { msg with content = content })


