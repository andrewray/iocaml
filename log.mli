(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: log file for debugging
 *
 *)

(* open log file *)
val open_log_file : string -> unit

(* write string to log file *)
val log : string -> unit

