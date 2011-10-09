open Cil_types
open Cil

let run () =
  let vis =
    object
      inherit Visitor.frama_c_inplace
      method vterm t =
        match t.term_node with
          | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne), t1, t2) ->
            Kernel.result
              "Term comparison between %a of type %a and %a of type %a"
              !Ast_printer.d_term t1 !Ast_printer.d_logic_type t1.term_type
              !Ast_printer.d_term t2 !Ast_printer.d_logic_type t2.term_type;
            DoChildren
          | _ -> DoChildren
      method vpredicate p =
        match p with
          | Prel ((Rlt | Rgt | Rle | Rge | Req | Rneq), t1, t2) ->
              Kernel.result
                "Predicate comparison between %a of type %a and %a of type %a"
                !Ast_printer.d_term t1 !Ast_printer.d_logic_type t1.term_type
                !Ast_printer.d_term t2 !Ast_printer.d_logic_type t2.term_type;
              DoChildren
          | _ -> DoChildren
    end
  in
  Visitor.visitFramacFileSameGlobals vis (Ast.get())
;;

let () = Db.Main.extend run
