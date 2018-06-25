[%%shared
    open Eliom_lib
    open Eliom_content
    open Html.D
]

module Test1_app =
  Eliom_registration.App (
    struct
      let application_name = "test1"
      let global_data_path = None
    end)

(*
let main_service =
  Eliom_service.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    ()

let () =
  Test1_app.register
    ~service:main_service
    (fun () () ->
      Lwt.return
        (Eliom_tools.F.html
           ~title:"test1"
           ~css:[["css";"test1.css"]]
           Html.F.(body [
             h4 [pcdata "Welcome from Eliom's distillery!"];
           ])))
*)

let f _ () =
  Lwt.return (Eliom_tools.F.html
			   ~title:"test1"
			   ~css:[["css";"test1.css"]]
			   Html.F.(body [
				 h4 [pcdata "Welcome from Eliom's distillery!"];
			   ]))

let main_service =
  (* create the service and register it at once *)
  Eliom_registration.Html.create
    ~path:(Eliom_service.Path ["aaa"; "bbb"])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    f

let g getp postp = Lwt.return ("t = " ^ (string_of_int postp))

let post_service =
  Eliom_registration.Html_text.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Post (Eliom_parameter.unit,Eliom_parameter.int "t"))
    g

let g' getp postp = Lwt.return "..."

let get_service =
  Eliom_registration.Html_text.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    g'
