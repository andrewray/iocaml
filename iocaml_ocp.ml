type index = LibIndex.t

let complete_request completion index socket msg x =
  if completion then
    let reply = Completion.complete index x in
    Message.send_h socket msg (Complete_reply reply)
  else
    ()

let object_info_request object_info index socket msg x =
  if object_info then
    let reply = Completion.info index x in
    Message.send_h socket msg (Object_info_reply reply)
  else
    ()

let index = Completion.init ()
