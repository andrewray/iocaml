
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

(*******************************************************************************)
(* main *)

let read_connection_info () = 
    let f_conn_info = open_in Sys.argv.(1) in
    let state = Yojson.init_lexer () in
    let lex = Lexing.from_channel f_conn_info in
    let conn = Ipython_json_j.read_connection_info state lex in
    let () = close_in f_conn_info in
    conn

let main  =  
    let () = Printf.printf "[iocaml] Starting kernel\n%!" in
    let () = Toploop.set_paths() in
    let () = !Toploop.toplevel_startup_hook() in
    let () = Toploop.initialize_toplevel_env() in
    try
        let conn = read_connection_info () in
        let sockets = Sockets.open_sockets conn in
        let hb_thread = Thread.create Sockets.heartbeat conn in
        ignore (hb_thread);
        Shell.run sockets
    with x -> begin
        Log.log (Printf.sprintf "Exception: %s\n" (Printexc.to_string x));
        exit 0
    end

