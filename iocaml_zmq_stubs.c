#include <zmq.h>
#include <caml/mlvalues.h>
#include <caml/threads.h>

/*
 * release then re-acquire ocaml runtime system during
 * zmq_msg_send/recv so threads continue to run.
 *
 */

int iocaml_zmq_msg_send(zmq_msg_t *msg, void *socket, int flags) {
  int ret;
  caml_release_runtime_system();
  ret = zmq_msg_send(msg, socket, flags);
  caml_acquire_runtime_system();
  return ret;
}

int iocaml_zmq_msg_recv(zmq_msg_t *msg, void *socket, int flags) {
  int ret;
  caml_release_runtime_system();
  ret = zmq_msg_recv(msg, socket, flags);
  caml_acquire_runtime_system();
  return ret;
}

/*
 * Constants
 *
 */

int iocaml_sizeof_zmq_msg_t(void) { return (int) sizeof(zmq_msg_t); }
#define PARAM(x) int iocaml_##x (void) { return x; }
PARAM(ZMQ_NOBLOCK)
PARAM(ZMQ_SNDMORE)
PARAM(ZMQ_RCVMORE)
PARAM(ZMQ_LINGER)
PARAM(ZMQ_SUBSCRIBE)
PARAM(ZMQ_IDENTITY)
PARAM(ZMQ_FD)
PARAM(ZMQ_POLLIN)
PARAM(ZMQ_POLLOUT)
PARAM(ZMQ_POLLERR)
PARAM(ZMQ_EVENTS)
PARAM(ZMQ_PAIR)
PARAM(ZMQ_PUB)
PARAM(ZMQ_SUB)
PARAM(ZMQ_REQ)
PARAM(ZMQ_REP)
PARAM(ZMQ_DEALER)
PARAM(ZMQ_ROUTER)
PARAM(ZMQ_PULL)
PARAM(ZMQ_PUSH)
PARAM(ZMQ_XPUB)
PARAM(ZMQ_XSUB)

