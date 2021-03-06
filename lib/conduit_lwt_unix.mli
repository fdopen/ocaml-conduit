(*
 * Copyright (c) 2012-2014 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2014 Hannes Mehnert <hannes@mehnert.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(** Connection establishment using the
    {{:http://ocsigen.org/lwt/api/Lwt_unix}Lwt_unix} library *)

open Sexplib.Conv

(** {2 Core types} *)

(** Configuration fragment for a TLS client connecting to a remote endpoint *)
type client_tls_config =
  [ `Hostname of string ] *
  [ `IP of Ipaddr.t ] *
  [ `Port of int ]
with sexp

(** Set of supported client connections that are supported by this module. *)
type client = [
  | `TLS of client_tls_config
  (** Use OCaml-TLS or OpenSSL (depending on CONDUIT_TLS) to connect to
      the given [host], [ip], [port] tuple via TCP *)
  | `TLS_native of client_tls_config
  (** Force use of native OCaml TLS stack to connect.*)
  | `OpenSSL of client_tls_config
  (** Force use of Lwt OpenSSL bindings to connect. *)
  | `TCP of [ `IP of Ipaddr.t ] * [`Port of int ]
  (** Use TCP to connect to the given [ip], [port] tuple. *)
  | `Unix_domain_socket of [ `File of string ]
  (** Use UNIX domain sockets to connect to a socket on the [path]. *)
  | `Vchan_direct of [ `Domid of int ] * [ `Port of string ]
  (** Connect to the remote VM on the [domid], [port] tuple. *)
  | `Vchan_domain_socket of [ `Domain_name of string ] * [ `Port of string ]
  (** Use the Vchan name resolution to connect *)
] with sexp

(** Configuration fragment for a listening TLS server *)
type server_tls_config =
  [ `Crt_file_path of string ] *
  [ `Key_file_path of string ] *
  [ `Password of bool -> string | `No_password ] *
  [ `Port of int ]
with sexp

(** Set of supported listening mechanisms that are supported by this module. *)
type server = [
  | `TLS of server_tls_config
  | `OpenSSL of server_tls_config
  | `TLS_native of server_tls_config
  | `TCP of [ `Port of int ]
  | `Unix_domain_socket of [ `File of string ]
  | `Vchan_direct of int * string
  | `Vchan_domain_socket of string  * string
] with sexp

type 'a io = 'a Lwt.t
type ic = Uwt_io.input_channel
type oc = Uwt_io.output_channel

(** [tcp_flow] contains the state of a single TCP connection. *)
type tcp_flow = private {
  fd: Uwt.Tcp.t sexp_opaque;
  ip: Ipaddr.t;
  port: int;
} with sexp_of

(** [domain_flow] contains the state of a single Unix domain socket
    connection. *)
type domain_flow = private {
  fd: Uwt.Pipe.t sexp_opaque;
  path: string;
} with sexp_of

(** [vchan_flow] contains the state of a single Vchan shared memory
    connection. *)
type vchan_flow = private {
  domid: int;
  port: string;
} with sexp_of

(** A [flow] contains the state of a single connection, over a specific
    transport method. *)
type flow = private
  | TCP of tcp_flow
  | Domain_socket of domain_flow
  | Vchan of vchan_flow
with sexp_of

(** Type describing where to locate a PEM key in the filesystem *)
type tls_server_key = [
 | `None
 | `TLS of
    [ `Crt_file_path of string ] *
    [ `Key_file_path of string ] *
    [ `Password of bool -> string | `No_password ]
] with sexp

(** State handler for an active conduit *)
type ctx with sexp_of

(** {2 Connection and listening} *)

(** Default context that listens on all source addresses with
    no TLS certificate associated with the Conduit *)
val default_ctx : ctx

(** [init ?src ?tls_server_key ()] will initialize a Unix conduit
    that binds to the [src] interface if specified.  If TLS server
    connections are used, then [tls_server_key] must contain a
    valid certificate to be used to advertise a TLS connection *)
val init : ?src:string -> ?tls_server_key:tls_server_key -> unit -> ctx io

(** [connect ~ctx client] establishes an outgoing connection
    via the [ctx] context to the endpoint described by [client] *)
val connect : ctx:ctx -> client -> (flow * ic * oc) io

(** [serve ?timeout ?stop ~ctx ~mode fn] establishes a listening
    connection of type [mode], using the [ctx] context.  The
    [stop] thread will terminate the server if it ever becomes
    determined.  Every connection will be served in a new
    lightweight thread that is invoked via the [fn] callback *)
val serve :
  ?timeout:int -> ?stop:(unit io) -> ctx:ctx ->
   mode:server -> (flow -> ic -> oc -> unit io) -> unit io

(** [endp_of_flow flow] retrieves the original {!Conduit.endp}
    from the established [flow] *)
val endp_of_flow : flow -> Conduit.endp

(** [endp_to_client ~ctx endp] converts an [endp] into a
    a concrete connection mechanism of type [client] *)
val endp_to_client : ctx:ctx -> Conduit.endp -> client io

(** [endp_to_server ~ctx endp] converts an [endp] into a
    a concrete connection mechanism of type [client] *)
val endp_to_server : ctx:ctx -> Conduit.endp -> server io

(** {2 TLS library selection} *)

(** Currently selected method of using TLS for client and servers *)
type tls_lib =
 | OpenSSL (** The [Lwt_ssl] bindings to the C OpenSSL library *)
 | Native  (** A pure OCaml TLS implementation *)
 | No_tls  (** No TLS implementation available, so any connections will fail *)

(** The default selection is to select {!OpenSSL}, {!Native} and {!No_tls} in
    decreasing order of priority.  The native OCaml stack can be forced by
    setting the [CONDUIT_TLS] Unix environment variable to [native]. *)
val tls_library : tls_lib ref
