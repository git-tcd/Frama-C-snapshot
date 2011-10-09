(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2011                                               *)
(*    CEA (Commissariat a l'�nergie atomique et aux �nergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Proof Script Database                                              --- *)
(* -------------------------------------------------------------------------- *)

let scriptbase = Hashtbl.create 81
let scriptfile = ref None (* current file script name *)
let needback   = ref true (* file script need backup before modification *)
let needsave   = ref true (* file script need to be saved *)

let clear () =
  begin
    Hashtbl.clear scriptbase ;
    scriptfile := None ;
    needback := false ;
    needsave := false ;
  end

let register_script goal keys proof =
  Hashtbl.replace scriptbase goal (List.sort String.compare keys,proof)

(* -------------------------------------------------------------------------- *)
(* --- Proof Scripts Parsers                                              --- *)
(* -------------------------------------------------------------------------- *)

open Script

let parse_coqproof file =
  let input = Script.open_file file in
  try
    let rec fetch_proof input =
      match token input with
        | Proof p -> Some p
        | Eof -> None
        | _ -> skip input ; fetch_proof input
    in
    let proof = fetch_proof input in
    Script.close input ; proof
  with e ->
    Script.close input ;
    raise e

let rec collect_scripts input =
  while key input "Goal" do
    let g = ident input in
    eat input "." ;
    let xs =
      if key input "Hint" then
        let xs = idents input in
        eat input "." ; xs
      else [] in
    let p =
      match token input with
        | Proof p -> skip input ; p
        | _ -> error input "Missing proof"
    in
    register_script g xs p
  done ;
  if token input <> Eof
  then error input "Unexpected script declaration"

let parse_scripts file =
  if Sys.file_exists file then
    begin
      let input = Script.open_file file in
      try
      collect_scripts input ;
        Script.close input ;
      with e ->
        Script.close input ;
        raise e
    end

let dump_scripts file =
  let out = open_out file in
  let fmt = Format.formatter_of_out_channel out in
  try
    Format.fprintf fmt "(* Generated by Frama-C (WP) *)@\n@\n" ;
    Hashtbl.iter
      (fun goal (keys,proof) ->
        Format.fprintf fmt "Goal %s.@\n" goal ;
        (match keys with
        | [] -> ()
        | k::ks ->
          Format.fprintf fmt "Hint %s" k ;
          List.iter (fun k -> Format.fprintf fmt ",%s" k) ks ;
          Format.fprintf fmt ".@\n");
        Format.fprintf fmt "Proof.@\n%sQed.@\n@." proof)
      scriptbase ;
    Format.pp_print_newline fmt () ;
    close_out out ;
  with e ->
    Format.pp_print_newline fmt () ;
    close_out out ;
    raise e

(* -------------------------------------------------------------------------- *)
(* --- Scripts Management                                                 --- *)
(* -------------------------------------------------------------------------- *)

let rec choose k =
  let file = Printf.sprintf "wp%d.script" k in
  if Sys.file_exists file then choose (succ k) else file

let savescripts () =
  if !needsave then
    match !scriptfile with
      | None -> ()
      | Some file ->
          try
            if !needback then
              ( Command.copy file (file ^ ".back") ; needback := false ) ;
            dump_scripts file ;
            needsave := false ;
          with e ->
            Wp_parameters.abort
              "Error when dumping script file '%s':@\n%s" file
              (Printexc.to_string e)

let loadscripts () =
  let user = Wp_parameters.Script.get () in
  if !scriptfile <> Some user then
    begin
      savescripts () ;
      let file =
        if user = "" then
          let ftmp = choose 0 in
          Wp_parameters.warning
            "No script file specified.@\n\
             Your proofs would be saved in '%s'@\n\
             Use -wp-script '%s' to re-run them."
            ftmp ftmp ;
          Wp_parameters.Script.set ftmp ;
          ftmp
        else
          user
      in
      scriptfile := Some file ;
      (* keep needsave *)
      if Sys.file_exists file then
        begin
          needback := true ;
          try parse_scripts user ;
          with e ->
            Wp_parameters.abort
              "Error in script file '%s':@\n%s" user
              (Printexc.to_string e)
        end
      else
        needback := false
    end

let find_script_for_goal goal =
  loadscripts () ;
  try Some(snd (Hashtbl.find scriptbase goal))
  with Not_found -> None

let rec suitable h mask keys =
  match mask , keys with
    | m::ms , k::ks ->
        let c = String.compare m k in
        if c < 0 then suitable h ms keys else
          if c > 0 then suitable h mask ks else
            suitable (succ h) ms ks
    | _ -> h

let most_suitable (h,_) (h',_) = h'-h

let find_script_for_keywords keys =
  loadscripts () ;
  Hashtbl.fold
    (fun _ (xs,p) scripts ->
       let h = suitable 0 xs keys in
       if h>0 then List.merge most_suitable [h,p] scripts
       else scripts)
    scriptbase []

let add_script goal keys proof =
  needsave := true ; register_script goal keys proof
