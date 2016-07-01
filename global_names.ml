(*
 * Taken with some modification from utop's uTop_complete.ml
 * ----------------
 * Copyright : (c) 2011, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *)

open Types

module String_set = Set.Make(String)

(* +-----------------------------------------------------------------+
   | Utils                                                           |
   +-----------------------------------------------------------------+ *)

(* Transform a non-empty list of strings into a long-identifier. *)
let longident_of_list = function
  | [] ->
      invalid_arg "UTop_complete.longident_of_list"
  | component :: rest ->
      let rec loop acc = function
        | [] -> acc
        | component :: rest -> loop (Longident.Ldot(acc, component)) rest
      in
      loop (Longident.Lident component) rest

(* Check whether an identifier is a valid one. *)
let is_valid_identifier id =
  id <> "" &&
    (match id.[0] with
       | 'A' .. 'Z' | 'a' .. 'z' |  '_' -> true
       | _ -> false)

let add id set = if is_valid_identifier id then String_set.add id set else set

let lookup_env f x env =
  try
    Some (f x env)
  with Not_found | Env.Error _ ->
    None

#if ocaml_version >= (4, 02)
let path () =
  let path_separator =
    match Sys.os_type with
    | "Unix" | "Cygwin" -> ':'
    | "Win32" -> ';'
    | _ -> assert false in
  let split str sep =
    let rec split_rec pos =
      if pos >= String.length str then [] else begin
        match try  Some (String.index_from str pos sep)
              with Not_found -> None with
        | Some newpos ->
          String.sub str pos (newpos - pos) ::
          split_rec (newpos + 1)
        | None ->
          [String.sub str pos (String.length str - pos)]
      end in
    split_rec 0
  in
  try
    split (Sys.getenv "PATH") path_separator
  with Not_found -> []
#endif

(* +-----------------------------------------------------------------+
   | Names listing                                                   |
   +-----------------------------------------------------------------+ *)

module Path_map = Map.Make(struct type t = Path.t let compare = compare end)
module Longident_map = Map.Make(struct type t = Longident.t let compare = compare end)

(* All names accessible with a path, by path. *)
let local_names_by_path = ref Path_map.empty

(* All names accessible with a path, by long identifier. *)
let local_names_by_longident = ref Longident_map.empty

(* All record fields accessible without a path. *)
let global_fields = ref None

(* All record fields accessible with a path, by path. *)
let local_fields_by_path = ref Path_map.empty

(* All record fields accessible with a path, by long identifier. *)
let local_fields_by_longident = ref Longident_map.empty

(* All visible modules according to Config.load_path. *)
let visible_modules = ref None

let reset () =
  visible_modules := None;
  local_names_by_path := Path_map.empty;
  local_names_by_longident := Longident_map.empty;
  global_fields := None;
  local_fields_by_path := Path_map.empty;
  local_fields_by_longident := Longident_map.empty

let get_cached var f =
  match !var with
  | Some x ->
    x
  | None ->
    let x = f () in
    var := Some x;
    x

(* List all visible modules. *)
let visible_modules () =
  get_cached visible_modules
    (fun () ->
      List.fold_left
        (fun acc dir ->
          try
            Array.fold_left
              (fun acc fname ->
                if Filename.check_suffix fname ".cmi" then
                  String_set.add (String.capitalize (Filename.chop_suffix fname ".cmi")) acc
                else
                  acc)
              acc
              (Sys.readdir (if dir = "" then Filename.current_dir_name else dir))
          with Sys_error _ ->
            acc)
        String_set.empty !Config.load_path)

#if ocaml_version >= (4, 02)
let field_name { ld_id = id } = Ident.name id
let constructor_name { cd_id = id } = Ident.name id
#else
let field_name (id, _, _) = Ident.name id
let constructor_name (id, _, _) = Ident.name id
#endif

let add_names_of_type decl acc =
  match decl.type_kind with
    | Type_variant constructors ->
        List.fold_left (fun acc cstr -> add (constructor_name cstr) acc) acc constructors
    | Type_record (fields, _) ->
        List.fold_left (fun acc field -> add (field_name field) acc) acc fields
    | Type_abstract ->
        acc
#if ocaml_version >= (4, 02)
    | Type_open ->
        acc
#endif

let rec names_of_module_type = function
  | Mty_signature decls ->
      List.fold_left
        (fun acc decl -> match decl with
           | Sig_value (id, _)
#if ocaml_version >= (4, 02)
           | Sig_typext (id, _, _)
#else
           | Sig_exception (id, _)
#endif
           | Sig_module (id, _, _)
           | Sig_modtype (id, _)
           | Sig_class (id, _, _)
           | Sig_class_type (id, _, _) ->
               add (Ident.name id) acc
           | Sig_type (id, decl, _) ->
               add_names_of_type decl (add (Ident.name id) acc))
        String_set.empty decls
  | Mty_ident path -> begin
      match lookup_env Env.find_modtype path !Toploop.toplevel_env with
#if ocaml_version < (4, 02)
        | Some Modtype_abstract -> String_set.empty
        | Some Modtype_manifest module_type -> names_of_module_type module_type
#else
        | Some { mtd_type = None } -> String_set.empty
        | Some { mtd_type = Some module_type } -> names_of_module_type module_type
#endif
        | None -> String_set.empty
    end
#if ocaml_version >= (4, 02)
  | Mty_alias path -> begin
      match lookup_env Env.find_module path !Toploop.toplevel_env with
        | None -> String_set.empty
        | Some { md_type = module_type } -> names_of_module_type module_type
    end
#endif
  | _ ->
      String_set.empty

#if ocaml_version < (4, 02)
let find_module = Env.find_module
#else
let find_module path env = (Env.find_module path env).md_type
#endif

let list_global_names () =
  let rec loop acc = function
    | Env.Env_empty -> acc
    | Env.Env_value(summary, id, _) ->
        loop (add (Ident.name id) acc) summary
    | Env.Env_type(summary, id, decl) ->
        loop (add_names_of_type decl (add (Ident.name id) acc)) summary
#if ocaml_version >= (4, 02)
    | Env.Env_extension(summary, id, _) ->
#else
    | Env.Env_exception(summary, id, _) ->
#endif
        loop (add (Ident.name id) acc) summary
    | Env.Env_module(summary, id, _) ->
        loop (add (Ident.name id) acc) summary
    | Env.Env_modtype(summary, id, _) ->
        loop (add (Ident.name id) acc) summary
    | Env.Env_class(summary, id, _) ->
        loop (add (Ident.name id) acc) summary
    | Env.Env_cltype(summary, id, _) ->
        loop (add (Ident.name id) acc) summary
#if ocaml_version >= (4, 02)
    | Env.Env_functor_arg(summary, id) ->
        loop (add (Ident.name id) acc) summary
#endif
    | Env.Env_open(summary, path) ->
        match try Some (Path_map.find path !local_names_by_path) with Not_found -> None with
          | Some names ->
              loop (String_set.union acc names) summary
          | None ->
              match lookup_env find_module path !Toploop.toplevel_env with
                | Some module_type ->
                    let names = names_of_module_type module_type in
                    local_names_by_path := Path_map.add path names !local_names_by_path;
                    loop (String_set.union acc names) summary
                | None ->
                    local_names_by_path := Path_map.add path String_set.empty !local_names_by_path;
                    loop acc summary
  in
  (* Add names of the environment: *)
  let acc = loop String_set.empty (Env.summary !Toploop.toplevel_env) in
  (* Add accessible modules: *)
  String_set.union acc (visible_modules ())

let get_global_names () =
  String_set.fold (fun s l -> s::l) (list_global_names()) []

