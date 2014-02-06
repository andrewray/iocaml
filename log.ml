(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: log file for debugging
 *
 *)

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
    Printf.sprintf "%i/%i/%i %.2i:%.2i:%.2i" 
        tm.tm_mday (tm.tm_mon+1) (tm.tm_year+1900) tm.tm_hour tm.tm_min tm.tm_sec

(* log time and command line *)
let () = log ("iocaml: " ^ (time()) ^ "\n")
let () = Array.iter (fun s -> log ("arg: " ^ s ^ "\n")) Sys.argv

