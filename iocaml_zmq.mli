(*

The ZMQ API has been taken from https://github.com/issuu/ocaml-zmq

Copyright (c) 2012 Hezekiah M. Carty

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*)
module ZMQ : sig
  module Context : sig
    type t
    val create : unit -> t
    val terminate : t -> unit
  end
  module Socket : sig
    type 'a t
    type 'a kind

    val pair   : [>`Pair] kind
    val pub    : [>`Pub] kind
    val sub    : [>`Sub] kind
    val req    : [>`Req] kind
    val rep    : [>`Rep] kind
    val dealer : [>`Dealer] kind
    val router : [>`Router] kind
    val pull   : [>`Pull] kind
    val push   : [>`Push] kind
    val xsub   : [>`Xsub] kind
    val xpub   : [>`Xpub] kind

    val create : Context.t -> 'a kind -> 'a t
    val close : 'a t -> unit
    val bind : 'a t -> string -> unit
    val connect : 'a t -> string -> unit

    val has_more : 'a t -> bool
    val get_fd : 'a t -> Unix.file_descr

    val set_linger_period : 'a t -> int -> unit
    val set_identity : 'a t -> string -> unit
    val subscribe : [> `Sub] t -> string -> unit

    val send : ?block:bool -> ?more:bool -> 'a t -> string -> unit
    val send_all : ?block:bool -> 'a t -> string list -> unit
    val recv : ?block:bool -> 'a t -> string
    val recv_all : ?block:bool -> 'a t -> string list

    type event = No_event | Poll_in | Poll_out | Poll_in_out | Poll_error
    val events : 'a t -> event

  end
end

(*
 
Taken from https://github.com/hcarty/lwt-zmq

Copyright (c) 2012 Hezekiah M. Carty

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*)
module Lwt_zmq : sig

  module Socket : sig

    type 'a t

    val of_socket : 'a ZMQ.Socket.t -> 'a t
    val to_socket : 'a t -> 'a ZMQ.Socket.t
    val recv : 'a t -> string Lwt.t
    val send : 'a t -> string -> unit Lwt.t
    val recv_all : 'a t -> string list Lwt.t
    val send_all : 'a t -> string list -> unit Lwt.t

  end

end
