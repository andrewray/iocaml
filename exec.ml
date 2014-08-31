type ('a,'b) status = Ok of 'a | Error of 'b

let get_error_loc = function 
#if ocaml_version > (4,0)
    | Syntaxerr.Error(x) -> Some(Syntaxerr.location_of_error x)
#endif
    | Lexer.Error(_, loc)
#if ocaml_version < (4,1)
    | Typecore.Error(loc, _)
    | Typetexp.Error(loc, _) 
    | Typeclass.Error(loc, _) 
    | Typemod.Error(loc, _) 
#else
    | Typecore.Error(loc, _, _)
    | Typetexp.Error(loc, _, _) 
    | Typeclass.Error(loc, _, _) 
    | Typemod.Error(loc, _, _) 
#endif
    | Typedecl.Error(loc, _) 
    | Translcore.Error(loc, _) 
    | Translclass.Error(loc, _) 
    | Translmod.Error(loc, _) -> Some(loc)
    | _ -> None

let buffer = Buffer.create 100 
let formatter = Format.formatter_of_buffer buffer 

let run_cell_lb execution_count lb = 

    let get_error_info exn = 
        Errors.report_error formatter exn;
        (match get_error_loc exn with
        | Some(loc) ->
#if ocaml_version < (4,2)
            ignore (Location.highlight_locations formatter loc Location.none);
#else
            ignore (Location.highlight_locations formatter [loc]);
#endif
        | None -> ());
        Format.pp_print_flush formatter ();
        Buffer.contents buffer
    in

    let cell_name = "["^string_of_int execution_count^"]" in
    Buffer.clear buffer;
    Location.init lb cell_name;
    Location.input_name := cell_name;
    Location.input_lexbuf := Some(lb);

    match try Ok(!Toploop.parse_use_file lb) with x -> Error(x) with
    | Error(exn) -> begin
        [Error(try get_error_info exn with _ -> "Syntax error.")]
    end
    | Ok(phrases) -> begin
        (* build a list of return messages (until there is an error) *)
        let rec run out_messages phrases =
            match phrases with
            | [] -> out_messages
            | phrase::phrases -> begin
                Buffer.clear buffer;
                match try Ok(Toploop.execute_phrase true formatter phrase)
                      with exn -> Error(exn) with
                | Ok(true) ->
                    let message = Buffer.contents buffer in
                    let out_messages = 
                        if message="" then out_messages else Ok(message)::out_messages 
                    in
                    run out_messages phrases
                | Ok(false) -> Error(Buffer.contents buffer) :: out_messages
                | Error(Sys.Break) -> Error("Interrupted.") :: out_messages
                | Error(exn) -> 
                    Error(try get_error_info exn with _ -> "Execution error.") :: out_messages
            end
        in
        List.rev (run [] phrases)
    end

let run_cell execution_count code = 
    run_cell_lb execution_count 
        (* little hack - make sure code ends with a '\n' otherwise the
         * error reporting isn't quite right *)
        Lexing.(from_string (code ^ "\n"))

let escape_html b = 
    let len = String.length b in
    let b' = Buffer.create len in
    for i=0 to len - 1 do
        match b.[i] with
        | '&' -> Buffer.add_string b' "&amp;"
        | '<' -> Buffer.add_string b' "&lt;" 
        | '>' -> Buffer.add_string b' "&gt;" 
        (*| '\'' -> Buffer.add_string b' "&apos;"*)
        | '\"' -> Buffer.add_string b' "&quot;" 
        | _ as x -> Buffer.add_char b' x
    done;
    Buffer.contents b'

let html_of_status message output_cell_max_height = 
    let output_styling colour data = 
        let onclick = "
onclick=\"
if (this.style.maxHeight === 'none') 
    this.style.maxHeight = '" ^ output_cell_max_height ^ "';
else
    this.style.maxHeight = 'none'; 
\"" 
        in
        "<pre style=\"color:" ^ colour ^ 
            ";max-height:" ^ output_cell_max_height ^ ";overflow:hidden\" " ^ 
            onclick ^ ">" ^ 
            escape_html data ^ 
        "</pre>" 
    in
    let data = 
        match message with
        | Ok(data) -> output_styling "slategray" data
        | Error(data) -> output_styling "red" data
    in
    data

