(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Top level loop and socket communications.
 *
 *)

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
        let suppress_stdout = ref false in
        let suppress_stderr = ref false in

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

    let suppress_compiler = ref false

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
    let execute = 
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
            let status = Exec.run_cell !execution_count (Lexing.from_string e.code) in
            Pervasives.(flush stdout; flush stderr); send_iopub Iopub_flush;
(*
            let send_display_data mime base64 f = 
                let str = read_stdout f in
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
*)
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

    let run sockets send_iopub =

        (* we are supposed to send state starting I think, but with what ids? *)
        (*send_iopub zero "starting";*)

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

            | Execute_request(x) -> execute sockets send_iopub msg x 

            | Shutdown_request(x) -> 
                (send_h sockets.shell msg (Shutdown_reply { restart = false });
                raise (Failure "Exiting"))

            | _ -> failwith ("shell: Unknown message " ^ msg.header.msg_type)

        done 

end

(*******************************************************************************)
(* main *)

let () = Printf.printf "[iocaml] Starting kernel\n%!" 
let () = Toploop.set_paths() 
let () = !Toploop.toplevel_startup_hook() 
let () = Toploop.initialize_toplevel_env() 

let connection_info = 
    let f_conn_info = open_in Sys.argv.(1) in
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

let suppress_stdout b = send_iopub (Shell.Iopub_suppress_stdout b)
let suppress_stderr b = send_iopub (Shell.Iopub_suppress_stderr b)
let suppress_compiler b = Shell.suppress_compiler := b
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

let main () =  
    try
        let _ = Thread.create Sockets.heartbeat connection_info in
        Shell.run sockets send_iopub
    with x -> begin
        Log.log (Printf.sprintf "Exception: %s\n" (Printexc.to_string x));
        exit 0
    end

