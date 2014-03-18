type ('a,'b) status = Ok of 'a | Error of 'b

val run_cell : int -> string -> (string,string) status list

val html_of_status : (string,string) status -> string -> string

