(* basic log file *)
module Log = struct

    let logging = true

    let log = 
        if logging then 
            let flog = open_out "iocaml.log" in
            let () = at_exit (fun () -> close_out flog) in
            (fun s -> output_string flog s; flush flog)
        else (fun s -> ())

    let time() = 
        let open Unix in
        let tm = localtime (time ()) in
        Printf.sprintf "%i/%i/%i %i:%i:%i" 
            tm.tm_mday (tm.tm_mon+1) (tm.tm_year+1900) tm.tm_hour tm.tm_min tm.tm_sec

    (* log time and command line *)
    let () = log ("iocaml: " ^ (time()) ^ "\n")
    let () = Array.iter (fun s -> log ("arg: " ^ s ^ "\n")) Sys.argv

end

(* code execution in the top level *)
module Exec = struct

    let buffer = Buffer.create 4096
    let formatter = Format.formatter_of_buffer buffer

    exception Exit
    let report_error x = 
        try (Errors.report_error formatter x; false)
        with x -> (Format.fprintf formatter "exn: %s@." (Printexc.to_string x); false)

    let run_cell execution_count lb =
        Buffer.clear buffer;
        Location.init lb ("["^string_of_int execution_count^"]");
        let success =
            try begin
                List.iter
                    (fun ph ->
                        Log.log("exec phrase\n");
                        if not (Toploop.execute_phrase true formatter ph) then raise Exit)
                    (!Toploop.parse_use_file lb);
                true
            end with
            | Exit -> false
            | Sys.Break -> (Format.fprintf formatter "Interrupted.@."; false)
            | x -> report_error x
        in
        success

end

(* read connection info structure *)
module ConnectionInfo = struct

    let read () = 
        let f_conn_info = open_in Sys.argv.(1) in
        let state = Yojson.init_lexer () in
        let lex = Lexing.from_channel f_conn_info in
        let conn = Ipython_json_j.read_connection_info state lex in
        let () = close_in f_conn_info in
        conn

end

module Message = struct

    open Ipython_json_t
    open Ipython_json_j

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

    let content_of_json hdr c = 
        match hdr.msg_type with
        | "connect_request" -> Connect_request
        | "kernel_info_request" -> Kernel_info_request
        | "shutdown_request" -> Shutdown_request(shutdown_of_string c)
        | "execute_request" -> Execute_request(execute_request_of_string c)
        | "connect_reply" -> Connect_reply(connect_reply_of_string c)
        | "kernel_info_reply" -> Kernel_info_reply(kernel_info_reply_of_string c)
        | "shutdown_reply" -> Shutdown_reply(shutdown_of_string c)
        | "execute_reply" -> Execute_reply(execute_reply_of_string c)
        | "status" -> Status(status_of_string c)
        | "pyin" -> Pyin(pyin_of_string c)
        | "stream" -> Stream(stream_of_string c)
        | "display_data" -> Display_data(display_data_of_string c)
        | _ -> failwith ("content_of_json: " ^ hdr.msg_type)

    let json_of_content = function
        | Connect_request -> "{}"
        | Kernel_info_request -> "{}"
        | Shutdown_request(x) -> string_of_shutdown x
        | Execute_request(x) -> string_of_execute_request x
        | Connect_reply(x) -> string_of_connect_reply x
        | Kernel_info_reply(x) -> string_of_kernel_info_reply x
        | Shutdown_reply(x) -> string_of_shutdown x
        | Execute_reply(x) -> string_of_execute_reply x
        | Status(x) -> string_of_status x
        | Pyin(x) -> string_of_pyin x
        | Stream(x) -> string_of_stream x
        | Display_data(x) -> string_of_display_data x

    let msg_type_of_content = function
        | Connect_request -> "connect_request"
        | Kernel_info_request -> "kernel_info_request"
        | Shutdown_request(_) -> "shutdown_request"
        | Execute_request(_) -> "execute_request"
        | Connect_reply(_) -> "connect_reply"
        | Kernel_info_reply(_) -> "kernel_info_reply"
        | Shutdown_reply(_) -> "shutdown_reply"
        | Execute_reply(_) -> "execute_reply"
        | Status(_) -> "status"
        | Pyin(_) -> "pyin"
        | Stream(_) -> "stream"
        | Display_data(_) -> "display_data"

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

end

module Sockets = struct

    let context = ZMQ.init ()
    let () = at_exit 
        (fun () ->
            Log.log "ZMQ.term\n"; 
            ZMQ.term context)

    let version = [3;2] (* XXX get from ZMQ *)

    let hb_addr conn port = 
        Ipython_json_j.(conn.transport ^ "://" ^ conn.ip ^ ":" ^ string_of_int port)

    let open_socket typ conn port = 
        let socket = ZMQ.Socket.(create context typ) in
        let addr = hb_addr conn port in
        let () = ZMQ.Socket.bind socket addr in
        Log.log ("open and bind socket " ^ addr ^ "\n");
        socket

    let heartbeat conn = 
        let socket = open_socket ZMQ.Socket.rep conn conn.Ipython_json_j.hb_port in
        while true do
            let data = ZMQ.Socket.recv socket in
            Log.log("Heartbeat\n");
            ZMQ.Socket.send socket data;
        done; 
        (* XXX close down properly...we never get here *)
        ZMQ.Socket.close socket
    
    type sockets = 
        {
            shell : [`Router] ZMQ.Socket.t;
            control : [`Router] ZMQ.Socket.t;
            stdin : [`Router] ZMQ.Socket.t;
            iopub : [`Pub] ZMQ.Socket.t;
        }

    let open_sockets conn =
        { 
            shell = open_socket ZMQ.Socket.router conn conn.Ipython_json_j.shell_port;
            control = open_socket ZMQ.Socket.router conn conn.Ipython_json_j.control_port;
            stdin = open_socket ZMQ.Socket.router conn conn.Ipython_json_j.stdin_port;
            iopub = open_socket ZMQ.Socket.pub conn conn.Ipython_json_j.iopub_port;
        }

    let dump name socket =
       while true do 
            let msg = Message.recv socket in
            let () = Message.log msg in
            ()
        done

end

module Shell = struct

    open Ipython_json_t 
    open Message
    open Sockets

    (* example mime types
        text/plain
        text/html
        application/json
        application/javascript
        image/png
        image/jpeg
        image/svg+xml
    *)

    let set_state sockets msg state = 
        send_h sockets.iopub msg (Status { execution_state = state })

    (* redirect stdio to pipes so we can capture and send them to the frontend *)
    let redirect_stdio () = 
        let stdin_p, stdin = Unix.pipe() in
        let stdout, stdout_p = Unix.pipe() in
        let stderr, stderr_p = Unix.pipe() in
        let () = Unix.dup2 stdin_p Unix.stdin in
        let () = Unix.dup2 stdout_p Unix.stdout in
        let () = Unix.dup2 stderr_p Unix.stderr in
        let () = Unix.set_nonblock stdout in
        let () = Unix.set_nonblock stderr in
        let () = at_exit 
            (fun () ->
                Unix.close stdin;
                Unix.close stdin_p;
                Unix.close stdout;
                Unix.close stdout_p;
                Unix.close stderr;
                Unix.close stderr_p)
        in
        stdin, stdout, stderr

    let mime_type = ref ""
    let base64 = ref false
    let suppress_stdout = ref false
    let suppress_stderr = ref false
    let suppress_compiler = ref false

    let set_suppress s = 
        let in_words s = (* from findlib Fl_split.in_words *)
            (* splits s in words separated by commas and/or whitespace *)
            let l = String.length s in
            let rec split i j =
                if j < l then
                    match s.[j] with
                    (' '|'\t'|'\n'|'\r'|',') ->
                        if i<j then (String.sub s i (j-i)) :: (split (j+1) (j+1))
                        else split (j+1) (j+1)
                    |    _ ->
                        split i (j+1)
                else
                    if i<j then [ String.sub s i (j-i) ] else []
          in
            split 0 0
        in
        let words = try in_words s with _ -> [] in
        List.iter (function
            | "compiler" -> suppress_compiler := true
            | "stdout" -> suppress_stdout := true
            | "stderr" -> suppress_stderr := true
            | "all" -> (suppress_compiler := true; suppress_stderr := true; suppress_stdout := true)
            | _ -> ()) words

    let () = Hashtbl.add Toploop.directive_table "mime" 
        (Toploop.Directive_string (fun s -> mime_type := s))
    let () = Hashtbl.add Toploop.directive_table "mime64" 
        (Toploop.Directive_string (fun s -> mime_type := s; base64 := true))
    let () = Hashtbl.add Toploop.directive_table "suppress" 
        (Toploop.Directive_string (fun s -> set_suppress s))

    (* read stdout (and stderr) *)
    let read_stdout =
        let b_len = 1024 in
        let buffer = String.create b_len in
        let rec read stdout =
            try (* read until we would block *)
                let r_len = Unix.read stdout buffer 0 b_len in
                let str = String.sub buffer 0 r_len in
                str ^ read stdout
            with _ -> ""
        in
        read

    (* execute code *)
    let execute = 
        let execution_count = ref 0 in
        (fun sockets (stdin,stdout,stderr) msg e ->

            (* XXX clear state *)
            mime_type := "";
            base64 := false;
            suppress_compiler := false;
            suppress_stdout := false;
            suppress_stderr := false;

            (* if we are not silent increment execution count *)
            (if not e.silent then incr execution_count);

            (* set state to busy *)
            set_state sockets msg "busy";
            send_h sockets.iopub msg
                    (Pyin {
                        pi_code = e.code;
                        pi_execution_count = !execution_count;
                    });

            (* eval code *)
            let status = Exec.run_cell !execution_count (Lexing.from_string e.code) in

            (* stdout and stderr *)
            let t_stdout = (Pervasives.stdout, stdout, "stdout") in
            let t_stderr = (Pervasives.stderr, stderr, "stderr") in

            (* messaging helpers *)
            let send_stream st_name st_data = 
                if st_data <> "" then send_h sockets.iopub msg (Stream { st_name; st_data })
            in
            let read_stdout (ps,us) = flush ps; read_stdout us in
            let send_stream_stdout (ps,us,ns) suppress = 
                let str = read_stdout (ps,us) in
                if not suppress then send_stream ns str
            in
            let send_display_data mime base64 (ps,us,ns) = 
                let str = read_stdout (ps,us) in
                let str = 
                    if not base64 then str
                    else Cryptokit.(transform_string (Base64.encode_multiline()) str)
                in
                send_h sockets.iopub msg
                    (Display_data {
                        dd_source = "ocaml";
                        dd_data = `Assoc [mime,`String str];
                        dd_metadata = `Assoc [];
                    })
            in

            (* output messages *)
            if status then begin
                (* execution ok *)
                send_h sockets.shell msg
                    (Execute_reply {
                        status = "ok";
                        execution_count = !execution_count;
                        ename = None;
                        evalue = None;
                        traceback = None;
                        payload = Some([]);
                        er_user_variables = Some(`Assoc[]);
                        er_user_expressions = Some(`Assoc[]);
                    });
                (* show compiler output *)
                (if not !suppress_compiler then send_stream "stdout" (Buffer.contents Exec.buffer));
                (* stdout or mime type *)
                (if !mime_type = "" then send_stream_stdout t_stdout !suppress_stdout
                else send_display_data !mime_type !base64 t_stdout);
                (* stderr *)
                send_stream_stdout t_stderr !suppress_stderr
            end else begin
                (* execution error *)
                send_h sockets.shell msg
                    (Execute_reply {
                        status = "error";
                        execution_count = !execution_count;
                        ename = Some("generic");
                        evalue = Some("error");
                        traceback = Some([]);
                        payload = None;
                        er_user_variables = None;
                        er_user_expressions = None;
                    });
                (* (always) show compiler output *)
                send_stream "stderr" (Buffer.contents Exec.buffer);
                (* stdout - suppress if mime type *)
                send_stream_stdout t_stdout (!suppress_stdout || !mime_type <> "");
                (* stderr *)
                send_stream_stdout t_stderr !suppress_stderr
            end;
            set_state sockets msg "idle";

        )

    let run sockets =
        let stdio = try redirect_stdio () with _ -> (Log.log("failed to redirect stdio\n"); exit 0) in
        (* we are supposed to send state starting I think *)
        (*set_state sockets Message.zero "starting";*)
        while true do
            let msg = recv sockets.shell in
            match msg.content with
            | Kernel_info_request ->
                send sockets.shell
                    (make_header { msg with
                        content = Kernel_info_reply { 
                            protocol_version = [ 3; 2 ];
                            language_version = [ 4; 1; 0 ];
                            language = "ocaml";
                        }
                    })

            | Execute_request(x) -> execute sockets stdio msg x

            | Shutdown_request(x) -> 
                (send_h sockets.shell msg (Shutdown_reply { restart = false });
                raise (Failure "Exiting"))

            | _ -> failwith ("shell: Unknown message " ^ msg.header.msg_type)

        done 

end

let main  =  
    let () = Printf.printf "[iocaml] Starting kernel\n%!" in
    let () = Toploop.set_paths() in
    let () = !Toploop.toplevel_startup_hook() in
    let () = Toploop.initialize_toplevel_env() in
    (* read connection info *)
    try
        let conn = ConnectionInfo.read () in
        let sockets = Sockets.open_sockets conn in
        let hb_thread = Thread.create Sockets.heartbeat conn in
        ignore (hb_thread);
        Shell.run sockets
    with x -> begin
        Log.log (Printf.sprintf "Exception: %s\n" (Printexc.to_string x));
        exit 0
    end

