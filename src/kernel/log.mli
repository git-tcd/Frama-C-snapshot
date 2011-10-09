(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2011                                               *)
(*    CEA (Commissariat � l'�nergie atomique et aux �nergies              *)
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
(** Logging Services for Frama-C Kernel and Plugins.
    @since Beryllium-20090601-beta1 *)
(* -------------------------------------------------------------------------- *)

open Format

type kind = Result | Feedback | Debug | Warning | Error | Failure
  (** @since Beryllium-20090601-beta1 *)

type event = {
  evt_kind : kind ;
  evt_plugin : string ;
  evt_source : Lexing.position option ;
  evt_message : string ;
}
  (** @since Beryllium-20090601-beta1 *)

type 'a pretty_printer =
    ?current:bool -> ?source:Lexing.position ->
    ?emitwith:(event -> unit) -> ?echo:bool -> ?once:bool ->
    ?append:(Format.formatter -> unit) ->
    ('a,formatter,unit) format -> 'a
  (**
      Generic type for the various logging channels which are not aborting
      Frama-C.
      - When [current] is [false] (default for most of the channels),
     no location is output. When it is [true], the last registred location
     is used as current (see {!Cil_const.CurrentLoc}).
     - [source] is the location to be output. If nil, [current] is used to
     determine if a location should be output
     - [emitwith] function which is called each time an event is processed
     - [echo] is [true] if the event should be output somewhere in addition
     to [stdout]
     - [append] adds some actions performed on the formatter after the event
     has been processed.
     @since Beryllium-20090601-beta1 *)

type ('a,'b) pretty_aborter =
    ?current:bool -> ?source:Lexing.position -> ?echo:bool ->
    ?append:(Format.formatter -> unit) ->
    ('a,formatter,unit,'b) format4 -> 'a
  (** @since Beryllium-20090601-beta1
      Same as {!Log.pretty_printer} except that channels having this type
      denote a fatal error aborting Frama-C.
   *)

(* -------------------------------------------------------------------------- *)
(** {2 Exception Registry}
    @plugin development guide
    @since Beryllium-20090601-beta1 *)
(* -------------------------------------------------------------------------- *)

exception AbortError of string (** Plug-in name *)
  (** User error that prevents a plugin to terminate.
      @since Beryllium-20090601-beta1 *)

exception AbortFatal of string (** Plug-in name *)
  (** Internal error that prevents a plugin to terminate.
      @since Beryllium-20090601-beta1 *)

exception FeatureRequest of string * string
  (** Raise by [not_yet_implemented].
      You may catch [FeatureRequest(p,r)] to support degenerated behavior.
      The responsible plugin is 'p' and the feature request is 'r'. *)

(* -------------------------------------------------------------------------- *)
(** {2 Plugin Interface}
    @plugin development guide
    @since Beryllium-20090601-beta1 *)
(* -------------------------------------------------------------------------- *)

(** @since Beryllium-20090601-beta1 *)
module type Messages = sig

  val verbose_atleast : int -> bool
    (** @since Beryllium-20090601-beta1 *)

  val debug_atleast : int -> bool
    (** @since Beryllium-20090601-beta1 *)

  val set_debug_keys : string list -> unit
    (** Keys for which debugging messages are printed by [debug] 
	with optional parameter [dkey]. 
	@since Nitrogen-20111001 *)
  val get_debug_keyset : unit -> string list
    (** Returns the registered debugging keys.
	Only activated if ["?"] is member of the current debugging keys. 
	@since Nitrogen-20111001 *)

  val result  : ?level:int -> 'a pretty_printer
    (** Results of analysis. Default level is 1.
        @since Beryllium-20090601-beta1 *)

  val feedback : ?level:int -> 'a pretty_printer
    (** Progress and feedback. Level is tested against the verbose.
        @since Beryllium-20090601-beta1 *)

  val debug   : ?level:int -> ?dkey:string -> 'a pretty_printer
    (** Debugging information dedicated to Plugin developpers.
        Default level is 1. The debugging key is used in message headers.
	See also [set_debug_keys] and [set_debug_keyset].
        @since Beryllium-20090601-beta1
	@modify Nitrogen-20111001 Optional parameter [dkey] *)

  val warning : 'a pretty_printer
    (** Hypothesis and restrictions.
        @since Beryllium-20090601-beta1 *)

  val error   : 'a pretty_printer
    (** user error: syntax/typing error, bad expected input, etc.
        @since Beryllium-20090601-beta1 *)

  val abort   : ('a,'b) pretty_aborter
    (** user error stopping the plugin.
        @raise AbortError with the channel name.
        @since Beryllium-20090601-beta1 *)

  val failure : 'a pretty_printer
    (** internal error of the plug-in. *)

  val fatal   : ('a,'b) pretty_aborter
    (** internal error of the plug-in.
        @raise AbortFatal with the channel name.
        @since Beryllium-20090601-beta1 *)

  val verify : bool -> ('a,bool) pretty_aborter
    (** If the first argument is [true], return [true] and do nothing else,
        otherwise, send the message on the {i fatal} channel and return
        [false].

        The intended usage is: [assert (verify e "Bla...") ;].
        @since Beryllium-20090601-beta1 *)

  val not_yet_implemented : ('a,formatter,unit,'b) format4 -> 'a
    (** raises [FeatureRequest] but {i do not} send any message.
        If the exception is not catched, Frama-C displays a feature-request
        message to the user.
        @since Beryllium-20090901 *)

  val deprecated: string -> now:string -> ('a -> 'b) -> ('a -> 'b)
    (** [deprecated s ~now f] indicates that the use of [f] of name [s] is now
        deprecated. It should be replaced by [now].
        @return the given function itself
        @since Lithium-20081201 in Extlib
        @since Beryllium-20090902 *)

  val with_result  : (event -> 'b) -> ('a,'b) pretty_aborter
    (** @since Beryllium-20090601-beta1 *)

  val with_warning : (event -> 'b) -> ('a,'b) pretty_aborter
    (** @since Beryllium-20090601-beta1 *)

  val with_error   : (event -> 'b) -> ('a,'b) pretty_aborter
    (** @since Beryllium-20090601-beta1 *)

  val with_failure : (event -> 'b) -> ('a,'b) pretty_aborter
    (** @since Beryllium-20090601-beta1 *)

  val log : ?kind:kind -> ?verbose:int -> ?debug:int -> 'a pretty_printer
    (** Generic log routine. The default kind is [Result]. Use cases (with
        [n,m > 0]):
        - [log ~verbose:n]: emit the message only when verbosity level is
        at least [n].
        - [log ~debug:n]: emit the message only when debugging level is
        at least [n].
        - [log ~verbose:n ~debug:m]: any debugging or verbosity level is
        sufficient.
        @since Beryllium-20090901 *)

  val with_log : (event -> 'b) -> ?kind:kind -> ('a,'b) pretty_aborter
    (** @since Beryllium-20090901 *)

  val register : kind -> (event -> unit) -> unit
    (** Local registry for listeners. *)

  val register_tag_handlers : (string -> string) * (string -> string) -> unit

end

(** Each plugin has its own channel to output messages.
    This functor should not be directly applied by plug-in developer.
    They should apply {!Plugin.Register} instead.
    @since Beryllium-20090601-beta1 *)
module Register
  (P : sig
     val channel : string
     val label : string
     val verbose_atleast : int -> bool
     val debug_atleast : int -> bool
   end)
  : Messages

(* -------------------------------------------------------------------------- *)
(** {2 Echo and Notification} *)
(* -------------------------------------------------------------------------- *)

val set_echo : ?plugin:string -> ?kind:kind list -> bool -> unit
  (** Turns echo on or off. Applies to all channel unless specified,
      and all kind of messages unless specified.
      @since Beryllium-20090601-beta1 *)

val add_listener : ?plugin:string -> ?kind:kind list -> (event -> unit) -> unit
  (** Register a hook that is called each time an event is
      emitted. Applies to all channel unless specified,
      and all kind of messages unless specified.
      @since Beryllium-20090601-beta1 *)

val echo : event -> unit
  (** Display an event of the terminal, unless echo has been turned off.
      @since Beryllium-20090601-beta1 *)

val notify : event -> unit
  (** Send an event over the associated listeners.
      @since Beryllium-20090601-beta1 *)

val reset_once_flag : unit -> unit
  (** Reset the [once] flag of pretty-printers. Messages already printed
      will be printed again.
      @since Boron-20100401 *)

(* -------------------------------------------------------------------------- *)
(** {2 Channel interface}
    This is the {i low-level} interface to logging services.
    Not to be used by casual users.
*)
(* -------------------------------------------------------------------------- *)

type channel
  (** @since Beryllium-20090601-beta1 *)

val new_channel : string -> channel
  (** @since Beryllium-20090901 *)

type prefix =
  | Label of string
  | Prefix of string
  | Indent of int

val log_channel : channel ->
  ?kind:kind -> ?prefix:prefix -> 'a pretty_printer
  (** logging function to user-created channel.
      @since Beryllium-20090901 *)

val with_log_channel : channel -> (event -> 'b) ->
  ?kind:kind -> ?prefix:prefix -> ('a,'b) pretty_aborter
  (** logging function to user-created channel.
      @since Beryllium-20090901 *)

val kernel_channel_name: string
  (** the reserved channel name used by the Frama-C kernel.
      @since Beryllium-20090601-beta1 *)

val kernel_label_name: string
  (** the reserved label name used by the Frama-C kernel.
      @since Beryllium-20090601-beta1 *)

(**/**)
val set_current_source : (unit -> Lexing.position) -> unit
  (* Forward reference to the function returning the current location,
      used when [~current:true] is set on printers. Currently set
      in {Cil}. Not for the casual user. *)
(**/**)

val get_current_source : unit -> Lexing.position

(* -------------------------------------------------------------------------- *)
(** {2 Terminal interface}
    This is the {i low-level} interface to logging services.
    Not to be used by casual users. *)
(* -------------------------------------------------------------------------- *)

val null : formatter
  (** Prints nothing.
      @since Beryllium-20090901 *)

val nullprintf :  ('a,formatter,unit) format -> 'a
  (** Discards the message and returns unit.
      @since Beryllium-20090901 *)

val with_null : (unit -> 'b) -> ('a,formatter,unit,'b) format4 -> 'a
  (** Discards the message and call the continuation.
      @since Beryllium-20090901 *)

val set_output : (string -> int -> int -> unit) -> (unit -> unit) -> unit
  (** This function has the same parameters as Format.make_formatter.
      @since Beryllium-20090901 *)

val print_on_output : (Format.formatter -> unit) -> unit
  (** Direct printing on output.
      Message echo is delayed until the output is finished.
      Then, the output is flushed and all pending message are echoed.
      Notification of listeners is not delayed, however.

      Can not be recursively invoked.
      @since Beryllium-20090901 
      @modify Nitrogen-20111001 signature changed *)

val print_delayed : (Format.formatter -> unit) -> unit
  (** Direct printing on output.  Same as [print_on_output], except
      that message echo is not delayed until text material is actually
      written. This gives an chance for formatters to emit messages
      before actual pretty printing.

      Can not be recursively invoked.
      @since Beryllium-20090901
      @modify Nitrogen-20111001 signature changed *)

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
