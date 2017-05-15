(* 
 * iocaml - an OCaml kernel for IPython
 *
 *   (c) 2014 MicroJamJar Ltd
 *
 * Author(s): andy.ray@ujamjar.com
 * Description: Use ocp-index to fill out the completion and object-info messages
 *
 *)

(* (simple) tab completion api *)
open Ipython_json_t

let pread_line cmd =
  try
    let ic = Unix.open_process_in (cmd ^ " 2>/dev/null") in
    let r = input_line ic in
    let r =
      let len = String.length r in
      if len>0 && r.[len - 1] = '\r' then String.sub r 0 (len-1) else r
    in
    match Unix.close_process_in ic with
    | Unix.WEXITED 0 -> [r]
    | _ -> []
  with
  | _ -> []

let empty_reply =
    {
        status = "ok";
        found = false;
        data = `Assoc [];
        metadata = `Assoc [];
    }

(* XXX we should probably allow user directories *)
let init () =
    (* get the ocamlc and opam library paths *)
    let paths = pread_line "ocamlc -where" @ pread_line "opam config var lib" in
    let paths = LibIndex.Misc.unique_subdirs paths in
    (* List.iter (fun p -> Log.log ("search path: " ^ p ^ "\n")) paths; *)
    LibIndex.load paths

let find_token_back line end_pos =
    let is_valid_char c = 
       (c >= 'a' && c <= 'z') || 
       (c >= 'A' && c <= 'Z') || 
       (c >= '0' && c <= '9') ||
       (c == '.') || (c == '_') || (c == '#') 
    in
    try 
        (* find start of token *)
        let rec start pos = 
            if pos < 0 then 0
            else if is_valid_char line.[pos] then start (pos-1)
            else pos+1
        in
        let start_pos = start (end_pos-1) in
        String.sub line start_pos (end_pos - start_pos)
    with _ -> 
        "exception"

let complete t req = 
    let token = find_token_back req.code req.cursor_pos in
    let matches = 
        try List.map LibIndex.Print.path (LibIndex.complete t token)
        with _ -> []
    in
    Log.log ("complete_req: match '" ^ token ^ "'\n");
    {
        matches = matches;
        cursor_start = req.cursor_pos - String.length token;
        cursor_end = req.cursor_pos;
        cr_status = "ok";
    }

let docstring_from_completion completion =
    let path = LibIndex.Print.path completion in
    let kind = LibIndex.Print.kind completion in
    let doc = LibIndex.Print.doc completion in
    let loc = LibIndex.Print.loc completion in
    (if kind <> "" then kind ^ " : " ^ path ^ "\n" else path ^ "\n") ^
    (if loc <> "<no location information>" then loc ^ "\n" else "") ^
    (if doc <> "" then "\n\n" ^ doc else "")

let info_from_name t name =
    match LibIndex.complete t name with
    | [] -> empty_reply
    | completion::_ ->
        {
            empty_reply with
                found = true;
                data = `Assoc [
                    "text/plain",
                    `String (docstring_from_completion completion);
                ];
        }

let info t (req: Ipython_json_t.inspect_request) =
    info_from_name t (find_token_back req.code req.cursor_pos)

