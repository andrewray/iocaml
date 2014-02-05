let context = ZMQ.init ()
let () = at_exit 
    (fun () ->
        Log.log "ZMQ.term\n"; 
        ZMQ.term context)

let version = [3;2] (* XXX get from ZMQ *)

let addr conn port = 
    Ipython_json_j.(conn.transport ^ "://" ^ conn.ip ^ ":" ^ string_of_int port)

let open_socket typ conn port = 
    let socket = ZMQ.Socket.(create context typ) in
    let addr = addr conn port in
    let () = ZMQ.Socket.bind socket addr in
    Log.log ("open and bind socket " ^ addr ^ "\n");
    socket

let heartbeat conn = 
    let socket = open_socket ZMQ.Socket.rep conn conn.Ipython_json_j.hb_port in
    while true do
        let data = ZMQ.Socket.recv socket in
        Log.log("Heartbeat\n");
        ZMQ.Socket.send socket data;
    done; 
    (* XXX close down properly...we never get here *)
    ZMQ.Socket.close socket

type sockets = 
    {
        shell : [`Router] ZMQ.Socket.t;
        control : [`Router] ZMQ.Socket.t;
        stdin : [`Router] ZMQ.Socket.t;
        iopub : [`Pub] ZMQ.Socket.t;
    }

let open_sockets conn =
    { 
        shell = open_socket ZMQ.Socket.router conn conn.Ipython_json_j.shell_port;
        control = open_socket ZMQ.Socket.router conn conn.Ipython_json_j.control_port;
        stdin = open_socket ZMQ.Socket.router conn conn.Ipython_json_j.stdin_port;
        iopub = open_socket ZMQ.Socket.pub conn conn.Ipython_json_j.iopub_port;
    }

let dump name socket =
   while true do 
        let msg = Message.recv socket in
        let () = Message.log msg in
        ()
    done

