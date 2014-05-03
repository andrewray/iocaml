(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: handle zmq sockets
 *
 *)

open Iocaml_zmq

type sockets = 
    {
        shell : [`Router] ZMQ.Socket.t;
        control : [`Router] ZMQ.Socket.t;
        stdin : [`Router] ZMQ.Socket.t;
        iopub : [`Pub] ZMQ.Socket.t;
    }

val heartbeat : Ipython_json_t.connection_info -> unit

val open_sockets : Ipython_json_t.connection_info -> sockets

val dump : string -> [`Router] ZMQ.Socket.t -> unit

