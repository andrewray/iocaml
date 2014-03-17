(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Top level loop, socket communications amd user API
 *
 *)

(*******************************************************************************)
(* command line *)

let connection_file_name = ref ""
let suppress_stdout = ref false
let suppress_stderr = ref false
let suppress_compiler = ref false
let packages = ref []
let completion = ref false
let object_info = ref false
let thread = ref false
type syntax = Syntax_none | Syntax_camlp4o | Syntax_camlp4r
let syntax = ref Syntax_none

let ci_stdin = ref 50000
let ci_shell = ref 50001
let ci_iopub = ref 50002
let ci_heartbeat = ref 50003
let ci_control = ref 50004
let ci_transport = ref "tcp"
let ci_ip_addr = ref ""

let () = 
    let suppress = 
        [
            "stdout",  (fun () -> suppress_stdout := true);
            "stderr",  (fun () -> suppress_stderr := true);
            "compiler",(fun () -> suppress_compiler := true);
            "all",     (fun () -> suppress_stdout := true;
                                  suppress_stderr := true;
                                  suppress_compiler := true);
        ]
    in
    let syntax = 
        [
            "none", (fun () -> syntax := Syntax_none);
            "camlp4o", (fun () -> syntax := Syntax_camlp4o);
            "camlp4r", (fun () -> syntax := Syntax_camlp4r);
        ]
    in
    let symbol s = Arg.Symbol(List.map fst s, (fun s' -> (List.assoc s' s) ())) in
    Arg.(parse
        (align [
            "-log", String(Log.open_log_file), "<filename> open log file";
            "-connection-file", Set_string(connection_file_name),
                "<filename> connection file name";
            "-suppress", symbol suppress, " suppress channel at start up";
            "-package", String(fun s -> packages := s :: !packages), 
                "<package> load package(s) at startup";
            "-thread", Set(thread), " enable system threads";
            "-syntax", symbol syntax, " enable camlp4 pre-processor";
            "-completion", Set(completion), " enable tab completion";
            "-object-info", Set(object_info), " enable introspection";
            (* pass connection info through command line *)
            "-ci-stdin", Set_int(ci_stdin), " (connection info) stdin zmq port";
            "-ci-iopub", Set_int(ci_iopub), " (connection info) iopub zmq port";
            "-ci-shell", Set_int(ci_shell), " (connection info) shell zmq port";
            "-ci-control", Set_int(ci_control), " (connection info) control zmq port";
            "-ci-heartbeat", Set_int(ci_heartbeat), " (connection info) heartbeat zmq port";
            "-ci-transport", Set_string(ci_transport), " (connection info) transport";
            "-ci-ip", Set_string(ci_ip_addr), " (connection info) ip address"
        ])
        (fun s -> failwith ("invalid anonymous argument: " ^ s)) 
        "iocaml kernel")

(*******************************************************************************)
(* code execution in the top level *)

module Exec = struct

    let buffer = Buffer.create 4096
    let formatter = Format.formatter_of_buffer buffer

    let get_error_loc = function 
        | Syntaxerr.Error(x) -> Syntaxerr.location_of_error x
        | Lexer.Error(_, loc) 
        | Typecore.Error(loc, _, _) 
        | Typetexp.Error(loc, _, _) 
        | Typedecl.Error(loc, _) 
        | Typeclass.Error(loc, _, _) 
        | Typemod.Error(loc, _, _) 
        | Translcore.Error(loc, _) 
        | Translclass.Error(loc, _) 
        | Translmod.Error(loc, _) -> loc
        | _ -> raise Not_found

    exception Exit
    let try_report_error x = 
        try begin
            Errors.report_error formatter x; 
            (try begin
                if Location.highlight_locations formatter (get_error_loc x) Location.none then 
                    Format.pp_print_flush formatter ()
            end with _ -> ()); 
            false
        end with x -> begin
            (* report_error will raise an exception when camlp4 is enabled, just ignore it. *)
            (*Format.fprintf formatter "%s@." (Printexc.get_backtrace());
            Format.fprintf formatter "report error exn: %s@." (Printexc.to_string x);*)
            false
        end

    let run_cell_lb execution_count lb =
        let cell_name = "["^string_of_int execution_count^"]" in
        Buffer.clear buffer;
        Location.init lb cell_name;
        Location.input_name := cell_name;
        Location.input_lexbuf := Some(lb);
        let success =
            try begin
                List.iter
                    (fun ph ->
                        if not (Toploop.execute_phrase true formatter ph) then raise Exit)
                    (!Toploop.parse_use_file lb);
                true
            end with
            | Exit -> false
            | Sys.Break -> (Format.fprintf formatter "Interrupted.@."; false)
            | x -> try_report_error x
        in
        success

    let run_cell execution_count code = run_cell_lb execution_count 
        (* little hack - make sure code ends with a '\n' otherwise the
         * error reporting isn't quite right *)
        Lexing.(from_string (code ^ "\n"))

end

(*******************************************************************************)
(* stdio hacks *)

module Stdio = struct

    type o_file = 
        {
            o_perv : Pervasives.out_channel;
            o_unix : Unix.file_descr;
            o_name : string;
        }
    type i_file = 
        {
            i_perv : Pervasives.in_channel;
            i_unix : Unix.file_descr;
            i_name : string;
        }

    let redirect () = 
        (* convert channels to binary mode. *)
        let () = 
            set_binary_mode_in stdin true;
            set_binary_mode_out stdout true;
            set_binary_mode_out stdout true
        in
        let stdin_p, stdin = Unix.pipe() in
        let stdout, stdout_p = Unix.pipe() in
        let stderr, stderr_p = Unix.pipe() in
        let mime_r, mime_w = Unix.pipe() in
        let () = Unix.dup2 stdin_p Unix.stdin in
        let () = Unix.dup2 stdout_p Unix.stdout in
        let () = Unix.dup2 stderr_p Unix.stderr in
        let () = at_exit 
            (fun () ->
                Unix.close stdin;
                Unix.close stdin_p;
                Unix.close stdout;
                Unix.close stdout_p;
                Unix.close stderr;
                Unix.close stderr_p;
                Unix.close mime_r;
                Unix.close mime_w)
        in
        {
            i_perv = Pervasives.stdin;
            i_unix = stdin;
            i_name = "stdin";
        },
        {
            o_perv = Pervasives.stdout;
            o_unix = stdout;
            o_name = "stdout";
        },
        {
            o_perv = Pervasives.stderr;
            o_unix = stderr;
            o_name = "stderr";
        },
        {
            i_perv = Unix.in_channel_of_descr mime_r;
            i_unix = mime_r;
            i_name = "mime";
        },
        {
            o_perv = Unix.out_channel_of_descr mime_w;
            o_unix = mime_w;
            o_name = "mime";
        }

end

(*******************************************************************************)
(* shell messages and iopub thread *)

module Shell = struct

    open Ipython_json_t 
    open Message
    open Sockets
    open Stdio

    type iopub_message = 
        | Iopub_set_current of message
        | Iopub_send_message of message_content
        | Iopub_send_raw_message of message
        | Iopub_suppress_stdout of bool
        | Iopub_suppress_stderr of bool
        | Iopub_flush
        | Iopub_send_mime of message option * string * bool
        | Iopub_get_current 
        | Iopub_stop

    type iopub_resp = 
        | Iopub_ok
        | Iopub_context of message option

    let escape_html b = 
        let len = Buffer.length b in
        let b' = Buffer.create len in
        for i=0 to len - 1 do
            match Buffer.nth b i with
            | '&' -> Buffer.add_string b' "&amp;"
            | '<' -> Buffer.add_string b' "&lt;" 
            | '>' -> Buffer.add_string b' "&gt;" 
            (*| '\'' -> Buffer.add_string b' "&apos;"*)
            | '\"' -> Buffer.add_string b' "&quot;" 
            | _ as x -> Buffer.add_char b' x
        done;
        b'

    let mime_message_content mime_type base64 data = 
        let data = 
            if not base64 then data
            else Base64.encode data
        in
        (Message.Display_data (Ipython_json_j.({
            dd_source = "ocaml";
            dd_data = `Assoc [mime_type,`String data];
            dd_metadata = `Assoc [];
        })))

    let handle_iopub (stdin,stdout,stderr,mime,_) (ctrl,resp) socket = 
        
        let rd_select r s a = 
            let r',_,_ = Thread.select (List.map fst r) [] [] s in
            List.fold_left (fun a (r,f) -> if List.mem r r' then f a else a) a r
        in

        let rec rd_select_loop r s a = 
            let stop = rd_select r s a in
            if stop then ()
            else rd_select_loop r s a
        in
        
        let msg = ref None in

        let send_output std suppress = 
            let buffer = String.create 1024 in
            let b_len = 1024 in
            fun _ ->
                let r_len = Unix.read std.o_unix buffer 0 b_len in
                match !msg, r_len, !suppress with
                | Some(msg), x, false when x <> 0 ->
                    let st_data = String.sub buffer 0 r_len in
                    send_h socket msg (Stream { st_name=std.o_name; st_data; });
                    false
                | _ -> false
        in

        let send_flush std suppress = 
            while Thread.select [std.o_unix] [] [] 0.0 <> ([],[],[]) do
                ignore (send_output std suppress ())
            done
        in

        let send_message content = 
            match !msg with
            | Some(msg) -> send_h socket msg content; false
            | None -> false
        in

        let send_raw_message msg = send socket msg; false in

        let mime_buffer = Buffer.create 1024 in
        let store_mime =
            let buffer = String.create 1024 in
            let b_len = 1024 in
            (fun _ ->
                let r_len = Unix.read mime.i_unix buffer 0 b_len in
                Buffer.add_substring mime_buffer buffer 0 r_len;
                false)
        in   
        let send_mime context mime_type base64 = 
            (* flush the mime channel *)
            while Thread.select [mime.i_unix] [] [] 0.0 <> ([],[],[]) do
                ignore (store_mime false)
            done;
            (* send mime message *)
            let data = Buffer.contents mime_buffer in
            let () = Buffer.clear mime_buffer in
            let content = mime_message_content mime_type base64 data in
            match context with
            | None -> send_message content
            | Some(context) -> (send_h socket context content; false)
        in

        let ctrl_message _ = 
            let return mesg res = Marshal.to_channel resp mesg []; flush resp; res in
            let ok res = return Iopub_ok res in
            match Marshal.from_channel ctrl.i_perv with
            | Iopub_set_current(m) -> msg := Some(m); ok false
            | Iopub_suppress_stdout(b) -> suppress_stdout := b; ok false
            | Iopub_suppress_stderr(b) -> suppress_stderr := b; ok false
            | Iopub_send_message(content) -> ok (send_message content)
            | Iopub_send_raw_message(msg) -> ok (send_raw_message msg)
            | Iopub_flush -> 
                send_flush stdout suppress_stdout;
                send_flush stderr suppress_stderr; ok false
            | Iopub_send_mime(context,mime_type,base64) -> 
                ok (send_mime context mime_type base64)
            | Iopub_get_current -> return (Iopub_context(!msg)) false
            | Iopub_stop -> ok true
        in

        rd_select_loop
            [
                stdout.o_unix, send_output stdout suppress_stdout;
                stderr.o_unix, send_output stderr suppress_stderr;
                mime.i_unix, store_mime;
                ctrl.i_unix, ctrl_message;
            ] (-1.) false

    let start_iopub stdio socket = 
        let r0,w0 = Unix.pipe () in
        let r1,w1 = Unix.pipe () in
        let _ = Thread.create
            (fun () -> 
                handle_iopub stdio
                    ({ i_perv = Unix.in_channel_of_descr r0; 
                       i_unix = r0; 
                       i_name = "iopub" }, 
                     Unix.out_channel_of_descr w1)
                    socket) ()
        in
        let w0 = Unix.out_channel_of_descr w0 in
        let r1 = Unix.in_channel_of_descr r1 in
        (* return a function to send messages to the iopub thread *)
        (fun message ->
            let () = (* send message to iopub *)
                Marshal.to_channel w0 message [];
                flush w0
            in
            let resp : iopub_resp = (* get response and return it *) 
                Marshal.from_channel r1 
            in
            resp)

    (* execute code *)
    let execute_request = 
        let execution_count = ref 0 in
        (fun sockets (send_iopub : iopub_message -> iopub_resp) msg e ->
            let send_iopub_u m = ignore (send_iopub m) in

            (* if we are not silent increment execution count *)
            (if not e.silent then incr execution_count);

            (* set state to busy *)
            send_iopub_u (Iopub_set_current msg);
            send_iopub_u (Iopub_send_message (Status { execution_state = "busy" }));
            send_iopub_u (Iopub_send_message
                    (Pyin {
                        pi_code = e.code;
                        pi_execution_count = !execution_count;
                    }));

            (* eval code *)
            let status = Exec.run_cell !execution_count e.code in
            Pervasives.flush stdout; Pervasives.flush stderr; send_iopub_u Iopub_flush;
    
            let pyout status = 
                (* XXX use classes *)
                let colour = if status then "color:slategray" else "color:red" in
                let buffer = Buffer.contents (escape_html Exec.buffer) in
                let data = "<pre style=\"" ^ colour ^ "\">" ^ buffer ^ "</pre>" in
                send_iopub_u (Iopub_send_message 
                    (Pyout { 
                        po_execution_count = !execution_count;
                        po_data = `Assoc [ "text/html", `String data ];
                        po_metadata = `Assoc []; }))
            in
            
            send_h sockets.shell msg
                (Execute_reply {
                    status = "ok";
                    execution_count = !execution_count;
                    ename = None; evalue = None; traceback = None; payload = None;
                    er_user_variables = None; er_user_expressions = None;
                });
            if (not status) || (not !suppress_compiler) then begin
                pyout status;
            end;
            
            (*
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
                if not !suppress_compiler then
                    send_iopub_u (Iopub_send_message 
                        (Stream { st_name="stdout"; st_data=Buffer.contents Exec.buffer }))
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
                send_iopub_u (Iopub_send_message 
                    (Stream { st_name="stderr"; st_data=Buffer.contents Exec.buffer }));
            end; *)
            send_iopub_u (Iopub_send_message (Status { execution_state = "idle" }));
        )

    let kernel_info_request socket msg = 
        send socket
            (make_header { msg with
                content = Kernel_info_reply { 
                    protocol_version = [ 3; 2 ];
                    language_version = [ 4; 1; 0 ];
                    language = "ocaml";
                }
            })

    let shutdown_request socket msg x = 
        (send_h socket msg (Shutdown_reply { restart = false });
        raise (Failure "Exiting"))

    let handle_invalid_message () = 
        raise (Failure "Invalid message on shell socket")

    let complete_request index socket msg x = 
        if !completion then 
            let reply = Completion.complete index x in
            send_h socket msg (Complete_reply reply)
        else
            ()

    let object_info_request index socket msg x = 
        if !object_info then
            let reply = Completion.info index x in
            send_h socket msg (Object_info_reply reply)
        else
            ()

    let connect_request socket msg = ()
    let history_request socket msg x = ()

    let run sockets send_iopub index =
        let () = Sys.catch_break true in
        (* we are supposed to send state starting I think, but with what ids? *)
        (*send_iopub zero "starting";*)

        let handle_message () = 
            let msg = recv sockets.shell in
            match msg.content with
            | Kernel_info_request -> kernel_info_request sockets.shell msg
            | Execute_request(x) -> execute_request sockets send_iopub msg x 
            | Connect_request -> connect_request sockets.shell msg 
            | Object_info_request(x) -> object_info_request index sockets.shell msg x
            | Complete_request(x) -> complete_request index sockets.shell msg x
            | History_request(x) -> history_request sockets.shell msg x
            | Shutdown_request(x) -> shutdown_request sockets.shell msg x

            (* messages we should not be getting *)
            | Connect_reply(_) | Kernel_info_reply(_)
            | Shutdown_reply(_) | Execute_reply(_)
            | Object_info_reply(_) | Complete_reply(_)
            | History_reply(_) | Status(_) | Pyin(_) 
            | Pyout(_) | Stream(_) | Display_data(_) 
            | Clear(_) -> handle_invalid_message ()
        in

        let rec run () = 
            try 
                handle_message(); run () 
            with Sys.Break -> 
                Log.log "Sys.Break\n"; run () 
        in
        run ()

end

(*******************************************************************************)
(* main *)

let () = Printf.printf "[iocaml] Starting kernel\n%!" 
(*let () = Sys.interactive := false*)
let () = Toploop.set_paths() 
let () = !Toploop.toplevel_startup_hook() 
let () = Toploop.initialize_toplevel_env() 

let connection_info = 
    if !ci_ip_addr <> "" then
        (* get configuration parameters from command line *)
        Ipython_json_t.({
            stdin_port = !ci_stdin;
            ip = !ci_ip_addr;
            control_port = !ci_control;
            hb_port = !ci_heartbeat;
            signature_scheme = "hmac-sha256";
            key = "";
            shell_port = !ci_shell;
            transport = !ci_transport;
            iopub_port = !ci_iopub;
        })
    else
        (* read from configuration files *)
        let f_conn_info = 
            try open_in !connection_file_name 
            with _ -> 
                failwith ("Failed to open connection file: '" ^ 
                         !connection_file_name ^ "'")  
        in
        let state = Yojson.init_lexer () in
        let lex = Lexing.from_channel f_conn_info in
        let conn = Ipython_json_j.read_connection_info state lex in
        let () = close_in f_conn_info in
        conn

let sockets = Sockets.open_sockets connection_info

let stdio = Stdio.redirect() 

type cell_context = Message.message option

let send_iopub = Shell.start_iopub stdio sockets.Sockets.iopub 
let send_message ?(context=None) msg = 
    match context with
    | None -> ignore (send_iopub (Shell.Iopub_send_message msg))
    | Some(context) ->
        ignore (send_iopub 
            Shell.(Iopub_send_raw_message(
                Message.(make_header 
                    { context with content = msg }))))

let send_flush () = 
    Pervasives.flush stdout;
    Pervasives.flush stderr;
    ignore (send_iopub Shell.Iopub_flush)
    
let index = Completion.init ()

let suppress_stdout b = ignore (send_iopub (Shell.Iopub_suppress_stdout b))
let suppress_stderr b = ignore (send_iopub (Shell.Iopub_suppress_stderr b))
let suppress_compiler b = suppress_compiler := b
let suppress_all b = 
    suppress_stdout b;
    suppress_stderr b;
    suppress_compiler b

let base64enc data = Base64.encode data

let data_uri ?(base64=true) mime_type data = 
    "\"data:" ^ mime_type ^ 
        (if base64 then 
            ";base64," ^ base64enc data
        else 
            "," ^ data) ^ "\""

let display ?context ?(base64=false) mime_type data = 
    send_message ?context Shell.(mime_message_content mime_type base64 data)

let mime = let _,_,_,_,m = stdio in m.Stdio.o_perv
let send_mime ?(context=None) ?(base64=false) mime_type = 
    flush mime;
    ignore (send_iopub Shell.(Iopub_send_mime(context,mime_type,base64)))

let send_clear ?(context=None) ?(wait=true) ?(stdout=true) ?(stderr=true) ?(other=true) () = 
    send_message ~context Shell.(Message.Clear(Ipython_json_t.({wait;stdout;stderr;other})))

let cell_context () = 
        match send_iopub Shell.Iopub_get_current with
        | Shell.Iopub_context(m) -> m
        | _ -> None

let () = 
    (* set startup options *)
    let command = 
"
let () =
  try Topdirs.dir_directory (Sys.getenv \"OCAML_TOPLEVEL_PATH\")
  with Not_found -> ()
;;

#use \"topfind\" ;;
"
    in
    let command = List.fold_left 
        (fun com (p,c) -> if p then com ^ c else com) command
        [
            !thread, "#thread;;\n";
            !syntax = Syntax_camlp4o, "#camlp4o;;\n"; 
            !syntax = Syntax_camlp4r, "#camlp4r;;\n";
            !packages <> [],
                "#require \"" ^ String.concat "," (List.rev !packages) ^ "\";;\n"
        ]
    in
    let status = Exec.run_cell (-1) command in
    Log.log (command);
    Log.log (Buffer.contents Exec.buffer);
    if not status then failwith "Couldn't load startup packages"

let () = Unix.putenv "TERM" "" (* make sure the compiler sees a dumb terminal *)

let main () =  
    try
        let _ = Thread.create Sockets.heartbeat connection_info in
        Shell.run sockets send_iopub index
    with x -> begin
        Log.log (Printf.sprintf "Exception: %s\n" (Printexc.to_string x));
        Log.log "Dying.\n";
        exit 0
    end

