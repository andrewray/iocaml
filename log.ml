(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: log file for debugging
 *
 *)

let log' = ref (fun s -> ())

let time() = 
    let open Unix in
    let tm = localtime (time ()) in
    Printf.sprintf "%i/%i/%i %.2i:%.2i:%.2i" 
        tm.tm_mday (tm.tm_mon+1) (tm.tm_year+1900) tm.tm_hour tm.tm_min tm.tm_sec

let open_log_file s = 
    (*let flog = open_out_gen [Open_text;Open_creat;Open_append] 0o666 s in*)
    let flog = open_out s in
    let () = at_exit (fun () -> close_out flog) in
    log' := (fun s -> output_string flog s; flush flog);
    !log' (Printf.sprintf "iocaml log file: %s\n" (time()))

let log s = !log' s

