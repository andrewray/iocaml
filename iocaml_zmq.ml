open Ctypes
open PosixTypes
open Foreign

module Stubs = struct

  let major, minor, patch = 
    let major = allocate int 0 in
    let minor = allocate int 0 in
    let patch = allocate int 0 in
    let zmq_version = foreign "zmq_version" (ptr int @-> ptr int @-> ptr int @-> returning void) in
    zmq_version major minor patch;
    (!@major,!@minor,!@patch)

  module Const = struct
    let const name = (foreign ("iocaml_" ^ name) (void @-> returning int)) ()

    let sizeof_zmq_msg_t = const "sizeof_zmq_msg_t" 

    (* send/recv flags *)
    let noblock   = const "ZMQ_NOBLOCK"
    let sndmore   = const "ZMQ_SNDMORE"
    let rcvmore   = const "ZMQ_RCVMORE"

    (* socket options *)
    let linger    = const "ZMQ_LINGER"
    let subscribe = const "ZMQ_SUBSCRIBE"
    let identity  = const "ZMQ_IDENTITY"
    let fd        = const "ZMQ_FD"

    (* socket events *)
    let pollin    = const "ZMQ_POLLIN"
    let pollout   = const "ZMQ_POLLOUT"
    let pollerr   = const "ZMQ_POLLERR"
    let events    = const "ZMQ_EVENTS"

    (* socket types *)
    let pair      = const "ZMQ_PAIR"
    let pub       = const "ZMQ_PUB"
    let sub       = const "ZMQ_SUB"
    let req       = const "ZMQ_REQ"
    let rep       = const "ZMQ_REP"
    let dealer    = const "ZMQ_DEALER"
    let router    = const "ZMQ_ROUTER"
    let pull      = const "ZMQ_PULL"
    let push      = const "ZMQ_PUSH"
    let xpub      = const "ZMQ_XPUB"
    let xsub      = const "ZMQ_XSUB"

    (* posix (unix) errors *)
    let eagain    = const "EAGAIN"
    let eintr     = const "EINTR"

  end

  type context
  let context : context structure typ = structure "zmq_context"

  type socket
  let socket : socket structure typ = structure "zmq_socket"

  type message
  let message : message structure typ = structure "zmq_msg_t"
  let _ = field message "message_struct_data" (array Const.sizeof_zmq_msg_t uchar) 
  (*let _ = field message "data0" uint64_t 
  let _ = field message "data1" uint64_t
  let _ = field message "data2" uint64_t
  let _ = field message "data3" uint64_t*)
  let () = seal message


  module Context = struct
    let create = foreign "zmq_ctx_new" ~check_errno:true 
      (void @-> returning (ptr context))
    (* XXX zmq_ctx_destroy on 3.2 *)
    let term = foreign (if major=4 then "zmq_ctx_term" else "zmq_ctx_destroy")
      (ptr context @-> returning int)
  end

  (* XXX XXX XXX *)
  external iocaml_zmq_msg_send : unit -> unit = "iocaml_zmq_msg_send"

  module Message = struct
    let close = foreign "zmq_msg_close" 
      (ptr message @-> returning int)
    let copy = foreign "zmq_msg_copy" 
      (ptr message @-> ptr message @-> returning int)
    let move = foreign "zmq_msg_move" 
      (ptr message @-> ptr message @-> returning int)
    let get = foreign "zmq_msg_get" 
      (ptr message @-> int @-> returning int)
    let set = foreign "zmq_msg_set" 
      (ptr message @-> int @-> int @-> returning int)
    let more = foreign "zmq_msg_more" 
      (ptr message @-> returning int)

    let init = foreign "zmq_msg_init" 
      (ptr message @-> returning int)
    let init_size = foreign "zmq_msg_init_size" 
      (ptr message @-> size_t @-> returning int)
    let free_fn_t = ptr void @-> ptr void @-> returning void
    let init_data = foreign "zmq_msg_init_data" 
      (ptr message @-> ptr void @-> size_t @-> funptr free_fn_t @-> ptr void @-> returning int)

    let size = foreign "zmq_msg_size" 
      (ptr message @-> returning size_t)
    let data = foreign "zmq_msg_data" 
      (ptr message @-> returning (ptr void))
    
    let send = foreign "iocaml_zmq_msg_send" 
      (ptr message @-> ptr socket @-> int @-> returning int)
    let recv = foreign "iocaml_zmq_msg_recv" 
      (ptr message @-> ptr socket @-> int @-> returning int)
  end

  module Socket = struct
    
    let create = foreign "zmq_socket" 
      (ptr context @-> int @-> returning (ptr socket))
    let close = foreign "zmq_close" 
      (ptr socket @-> returning int)
    
    let bind = foreign "zmq_bind" 
      (ptr socket @-> string @-> returning int)
    let connect = foreign "zmq_connect" 
      (ptr socket @-> string @-> returning int)
    
    let getsockopt = foreign "zmq_getsockopt"
      (ptr socket @-> int @-> ptr void @-> ptr size_t @-> returning int)
    let setsockopt = foreign "zmq_setsockopt"
      (ptr socket @-> int @-> ptr void @-> size_t @-> returning int)
    let setsockopt_string = foreign "zmq_setsockopt"
      (ptr socket @-> int @-> string @-> size_t @-> returning int)

  end

  module Utils = struct
    let memcpy_to_string = foreign "memcpy" 
      (string @-> ptr void @-> size_t @-> returning (ptr void))
    let memcpy_from_string = foreign "memcpy" 
      (ptr void @-> string @-> size_t @-> returning (ptr void))
    let strerror = foreign "zmq_strerror"
      (int @-> returning string)
    let errno = foreign "zmq_errno"
      (void @-> returning int)
  end

end

(* make API compatible(ish) with ocaml-zmq *)
module ZMQ = struct

  exception Zmq_exception of int * string * string

  let raise_if s x = 
    if x == -1 then
      let errno = Stubs.Utils.errno () in
      let errstr = Stubs.Utils.strerror errno in
      (* map these to posix errors for Zmq_lwt *)
      if errno = Stubs.Const.eagain then raise Unix.(Unix_error(EAGAIN, errstr, ""))
      else if errno = Stubs.Const.eintr then raise Unix.(Unix_error(EINTR, errstr, ""))
      (* otherwise use a zmq expection *)
      else raise (Zmq_exception(errno, s, errstr))
    else ()

  module Context = struct

    type t = Stubs.context structure ptr

    let create () = Stubs.Context.create ()
    let terminate ctx = Stubs.Context.term ctx |> raise_if "terminate"

  end

  module Socket = struct

    type 'a t = Stubs.socket structure ptr
    type 'a kind = int

    let pair   = Stubs.Const.pair
    let pub    = Stubs.Const.pub
    let sub    = Stubs.Const.sub
    let req    = Stubs.Const.req
    let rep    = Stubs.Const.rep
    let dealer = Stubs.Const.dealer
    let router = Stubs.Const.router
    let pull   = Stubs.Const.pull
    let push   = Stubs.Const.push
    let xpub   = Stubs.Const.xpub
    let xsub   = Stubs.Const.xsub

    let create ctx kind = Stubs.Socket.create ctx kind
    let close s = Stubs.Socket.close s |> raise_if "socket close"

    let bind s v = Stubs.Socket.bind s v |> raise_if "socket bind"
    let connect s v = Stubs.Socket.connect s v |> raise_if "socket connect"

    (* options *)

    let sizeof_int = Unsigned.Size_t.of_int (sizeof int)

    let get_int_option socket option = 
      let x = allocate int 0 in
      let size = allocate size_t sizeof_int in
      let () = Stubs.Socket.getsockopt socket option (to_voidp x) size 
                |> raise_if "getsockopt" in
      !@ x

    let set_int_option socket option value = 
      let x = allocate int value in
      let () = Stubs.Socket.setsockopt socket option (to_voidp x) sizeof_int 
                |> raise_if "setsockopt" in
      ()

    let set_bytes_option socket option value = 
      let size = Unsigned.Size_t.of_int (String.length value) in
      let () = Stubs.Socket.setsockopt_string socket option value size 
        |> raise_if "setsockopt_string" in
      ()

    let has_more socket = get_int_option socket Stubs.Const.rcvmore <> 0
    let get_fd socket = 
      get_int_option socket Stubs.Const.fd |> Obj.magic (* XXX Yikes... *)

    let set_linger_period socket linger = set_int_option socket Stubs.Const.linger linger
    let set_identity socket identity = set_bytes_option socket Stubs.Const.identity identity
    let subscribe socket topic = set_bytes_option socket Stubs.Const.subscribe topic

    let send ?(block=true) ?(more=false) socket m = 
      (* set flag *)
      let flag = if block then 0 else Stubs.Const.noblock in
      let flag = (if more then Stubs.Const.sndmore else 0) lor flag in

      (* init message *)
      let size = String.length m in
      let size_t = Unsigned.Size_t.of_int size in
      let msg = make Stubs.message in
      let p_msg = addr msg in
      let () = Stubs.Message.init_size p_msg size_t |> raise_if "msg init size" in

      (* fill out message data *)
      let data = CArray.from_ptr (from_voidp char (Stubs.Message.data p_msg)) size in
      for i=0 to size-1 do
        CArray.set data i m.[i]
      done;

      (* send message *)
      let () = Stubs.Message.send p_msg socket flag |> raise_if "send" in

      (* clean up message *)
      let () = Stubs.Message.close p_msg |> raise_if "msg close" in
      ()

    let recv ?(block=true) socket =
      let flag = if block then 0 else Stubs.Const.noblock in

      (* init message *)
      let msg = make Stubs.message in
      let p_msg = addr msg in
      let () = Stubs.Message.init p_msg |> raise_if "msg init" in

      (* receive message *)
      let r_size = Stubs.Message.recv p_msg socket flag in
      let () = r_size |> raise_if "recv" in
      
      (* form result *)
      let size_t = Stubs.Message.size p_msg in
      let size = Unsigned.Size_t.to_int size_t in

      let data = CArray.from_ptr (from_voidp char (Stubs.Message.data p_msg)) size in
      let result = String.create size in
      for i=0 to size-1 do
        result.[i] <- CArray.get data i
      done;
      (* clean up message *)
      let () = Stubs.Message.close p_msg |> raise_if "msg close" in
      result

    let recv_all =
      (* Once the first message part is received all remaining message parts can
        be received without blocking. *)
      let rec loop socket accu =
        if has_more socket then
          loop socket (recv socket :: accu)
        else
          accu
      in
      fun ?block socket ->
        let first = recv ?block socket in
        List.rev (loop socket [first])

    let send_all =
      (* Once the first message part is sent all remaining message parts can
        be sent without blocking. *)
      let rec send_all_inner_loop socket message =
        match message with
        | [] -> ()
        | hd :: [] ->
          send socket hd
        | hd :: tl ->
          send ~more:true socket hd;
          send_all_inner_loop socket tl
      in
      fun ?block socket message ->
        match message with
        | [] -> ()
        | hd :: [] ->
          send ?block ~more:false socket hd
        | hd :: tl ->
          send ?block ~more:true socket hd;
          send_all_inner_loop socket tl

    type event = No_event | Poll_in | Poll_out | Poll_in_out | Poll_error

    let events socket = 
      let x = allocate uint32_t (Unsigned.UInt32.of_int 0) in
      let size = allocate size_t sizeof_int in
      let () = Stubs.Socket.getsockopt socket Stubs.Const.events (to_voidp x) size 
                |> raise_if "getsockopt" in
      let x = !@ x in
      let open Unsigned.UInt32 in
      let bitset x mask =
        let z = of_int 0 in
        let m = of_int mask in
        compare Infix.(x land m) z <> 0
      in
      let pollin = bitset x Stubs.Const.pollin in
      let pollout = bitset x Stubs.Const.pollout in
      let pollerr = bitset x Stubs.Const.pollerr in
      if pollerr then Poll_error
      else if pollin && pollout then Poll_in_out
      else if pollin then Poll_in
      else if pollout then Poll_out
      else No_event

  end

end

module Lwt_zmq = struct

  module Socket = struct

    type 'a t = {
      socket : 'a ZMQ.Socket.t;
      fd : Lwt_unix.file_descr;
    }

    exception Break_event_loop

    let of_socket socket = {
      socket;
      fd = Lwt_unix.of_unix_file_descr ~blocking:false ~set_flags:false (ZMQ.Socket.get_fd socket);
    }

    let to_socket s = s.socket

    (* Wrap possible exceptions and events which can occur in a ZeroMQ call *)
    let wrap f s =
      let io_loop () =
        Lwt_unix.wrap_syscall Lwt_unix.Read s.fd (
          fun () ->
            try
              (* Check for zeromq events *)
              match ZMQ.Socket.events s.socket with
              | ZMQ.Socket.No_event -> raise Lwt_unix.Retry
              | ZMQ.Socket.Poll_in
              | ZMQ.Socket.Poll_out
              | ZMQ.Socket.Poll_in_out -> f s.socket
              (* This should not happen as far as I understand *)
              | ZMQ.Socket.Poll_error -> assert false
            with
            (* Not ready *)
            | Unix.Unix_error (Unix.EAGAIN, _, _) -> raise Lwt_unix.Retry
            (* We were interrupted so we need to start all over again *)
            | Unix.Unix_error (Unix.EINTR, _, _) -> raise Break_event_loop
        )
      in
      let rec idle_loop () =
        try_lwt
          Lwt.wrap1 f s.socket
        with
        | Unix.Unix_error ( Unix.EAGAIN, _, _) -> begin
          try_lwt
            io_loop ()
          with
          | Break_event_loop -> idle_loop ()
        end
        | Unix.Unix_error (Unix.EINTR, _, _) -> 
            idle_loop ()
      in
      idle_loop ()

    let recv s =
      wrap (fun s -> ZMQ.Socket.recv ~block:false s) s

    let send s m =
      wrap (fun s -> ZMQ.Socket.send ~block:false s m) s

    let recv_all s =
      wrap (fun s -> ZMQ.Socket.recv_all ~block:false s) s

    let send_all s parts =
      wrap (fun s -> ZMQ.Socket.send_all ~block:false s parts) s

  end

end

(*
let () = Printf.printf "ZMQ version: %i.%i.%i\n" major minor patch
let zmq = Stubs.Context.create ()
let sock = Stubs.Socket.create zmq Stubs.(int_of_kind Pub) 
let b_res = Stubs.Socket.bind sock "tcp://127.0.0.1:11111"
let c_res = Stubs.Socket.close sock 
let _ = Stubs.Context.term zmq
let () = Printf.printf "Finishing %i %i\n" b_res c_res
*)

