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
    Arg.(parse
        (align [
            "-log", String(Log.open_log_file), 
                "<filename> open log file";
            "-connection-file", Set_string(connection_file_name),
                "<filename> connection file name";
            "-suppress", Symbol(List.map fst suppress, (fun s -> (List.assoc s suppress) ())), 
                " suppress channel at start up";
            "-package", String(fun s -> packages := s :: !packages), 
                "<package> load package at startup";
            "-completion", Set(completion), " enable tab completion";
            "-object-info", Set(object_info), " enable introspection";
        ])
        (fun s -> failwith ("invalid anonymous argument: " ^ s)) 
        "iocaml kernel")

(*******************************************************************************)
(* code execution in the top level *)

module Exec = struct

    let buffer = Buffer.create 4096
    let formatter = Format.formatter_of_buffer buffer

#if ocaml_version > (4, 0)
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
#else
    let get_error_loc = function 
        | Lexer.Error(_, loc) 
        | Typecore.Error(loc, _) 
        | Typetexp.Error(loc, _) 
        | Typedecl.Error(loc, _) 
        | Typeclass.Error(loc, _) 
        | Typemod.Error(loc, _) 
        | Translcore.Error(loc, _) 
        | Translclass.Error(loc, _) 
        | Translmod.Error(loc, _) -> loc
        | _ -> raise Not_found
#endif

    exception Exit
    let report_error x = 
        try begin
            Errors.report_error formatter x; 
            (try begin
                if Location.highlight_locations formatter (get_error_loc x) Location.none then 
                    Format.pp_print_flush formatter ()
            end with _ -> ()); 
            false
        end with x -> (* shouldn't happen any more *) 
            (Format.fprintf formatter "exn: %s@." (Printexc.to_string x); false)

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
            | x -> report_error x
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
        | Iopub_suppress_stdout of bool
        | Iopub_suppress_stderr of bool
        | Iopub_flush
        | Iopub_send_mime of string * bool
        | Iopub_stop

    let mime_message_content mime_type base64 data = 
        let data = 
            if not base64 then data
            else Cryptokit.(transform_string (Base64.encode_multiline()) data)
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

        let mime_buffer = Buffer.create 1024 in
        let store_mime =
            let buffer = String.create 1024 in
            let b_len = 1024 in
            (fun _ ->
                let r_len = Unix.read mime.i_unix buffer 0 b_len in
                Buffer.add_substring mime_buffer buffer 0 r_len;
                false)
        in   
        let send_mime mime_type base64 = 
            (* flush the mime channel *)
            while Thread.select [mime.i_unix] [] [] 0.0 <> ([],[],[]) do
                ignore (store_mime false)
            done;
            (* send mime message *)
            let data = Buffer.contents mime_buffer in
            let () = Buffer.clear mime_buffer in
            send_message (mime_message_content mime_type base64 data)
        in

        let ctrl_message _ = 
            let res = 
                match Marshal.from_channel ctrl.i_perv with
                | Iopub_set_current(m) -> msg := Some(m); false
                | Iopub_suppress_stdout(b) -> suppress_stdout := b; false
                | Iopub_suppress_stderr(b) -> suppress_stderr := b; false
                | Iopub_send_message(content) -> send_message content
                | Iopub_flush -> send_flush stdout suppress_stdout;
                                 send_flush stderr suppress_stderr; false
                | Iopub_send_mime(mime_type,base64) -> send_mime mime_type base64
                | Iopub_stop -> true
            in
            output_char resp 'x'; flush resp;
            res
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
            Marshal.to_channel w0 message [];
            flush w0;
            ignore (input_char r1))

    (* execute code *)
    let execute_request = 
        let execution_count = ref 0 in
        (fun sockets send_iopub msg e ->

            (* if we are not silent increment execution count *)
            (if not e.silent then incr execution_count);

            (* set state to busy *)
            send_iopub (Iopub_set_current msg);
            send_iopub (Iopub_send_message (Status { execution_state = "busy" }));
            send_iopub (Iopub_send_message
                    (Pyin {
                        pi_code = e.code;
                        pi_execution_count = !execution_count;
                    }));

            (* eval code *)
            let status = Exec.run_cell !execution_count e.code in
            Pervasives.flush stdout; Pervasives.flush stderr; send_iopub Iopub_flush;

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
                    send_iopub (Iopub_send_message 
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
                send_iopub (Iopub_send_message 
                    (Stream { st_name="stderr"; st_data=Buffer.contents Exec.buffer }));
            end;
            send_iopub (Iopub_send_message (Status { execution_state = "idle" }));
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
            | Pyout(_) | Stream(_) | Display_data(_) -> handle_invalid_message ()
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
let () = Sys.interactive := false
let () = Toploop.set_paths() 
let () = !Toploop.toplevel_startup_hook() 
let () = Toploop.initialize_toplevel_env() 

let connection_info = 
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

let send_iopub = Shell.start_iopub stdio sockets.Sockets.iopub 
let send_message msg = send_iopub (Shell.Iopub_send_message msg)
let send_flush () = send_iopub Shell.Iopub_flush

let index = Completion.init ()

let suppress_stdout b = send_iopub (Shell.Iopub_suppress_stdout b)
let suppress_stderr b = send_iopub (Shell.Iopub_suppress_stderr b)
let suppress_compiler b = suppress_compiler := b
let suppress_all b = 
    suppress_stdout b;
    suppress_stderr b;
    suppress_compiler b

let display ?(base64=false) mime_type data = 
    let data = 
        if not base64 then data
        else Cryptokit.(transform_string (Base64.encode_multiline()) data)
    in
    send_message Shell.(mime_message_content mime_type base64 data)

let mime = let _,_,_,_,m = stdio in m.Stdio.o_perv
let send_mime ?(base64=false) mime_type = 
    flush mime;
    send_iopub Shell.(Iopub_send_mime(mime_type,base64))

let () = 
    (* load startup packages, if any *)
    if !packages <> [] then begin
        let command = 
"
let () =
  try Topdirs.dir_directory (Sys.getenv \"OCAML_TOPLEVEL_PATH\")
  with Not_found -> ()
;;

#use \"topfind\" ;;
#thread ;;
#camlp4o ;;
#require \"" ^ String.concat "," (List.rev !packages) ^ "\";;
"
        in
        let status = Exec.run_cell (-1) command in
        Log.log (command);
        Log.log (Buffer.contents Exec.buffer);
        if not status then failwith "Couldn't load startup packages"
    end

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

