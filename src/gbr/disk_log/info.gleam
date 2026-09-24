////
//// GBR: Erlang Disk Log Info Module
////

import gleam/dynamic/decode.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/option.{type Option}

import gbr/disk_log/options

//
// ----- Tipos auxiliares
//

/// Informações detalhadas sobre o disk_log.
///
/// -type dlog_info() ::
///  {name, Log :: log()} |
///  {file, File :: file:filename()} |
///  {type, Type :: dlog_type()} |
///  {format, Format :: dlog_format()} |
///  {size, Size :: dlog_size()} |
///  {mode, Mode :: dlog_mode()} |
///  {owners, [{pid(), Notify :: boolean()}]} |
///  {users, Users :: non_neg_integer()} |
///  {status, Status :: ok | {blocked, QueueLogRecords :: boolean()}} |
///  {node, Node :: node()} |
///  {head, Head :: none | {head, binary()} | (MFA :: {atom(), atom(), list()})} |
///  {no_written_items, NoWrittenItems :: non_neg_integer()} |
///  {full, Full :: boolean} |
///  {no_current_bytes, non_neg_integer()} |
///  {no_current_items, non_neg_integer()} |
///  {no_items, non_neg_integer()} |
///  {current_file, pos_integer()} |
///  {no_overflows, {SinceLogWasOpened :: non_neg_integer(), SinceLastInfo :: non_neg_integer()}}.
pub type DiskLogInfo {
  Name(atom.Atom)
  File(charlist.Charlist)
  Type(options.LogType)
  Format(options.LogFormat)
  Size(options.LogSize)
  Mode(options.LogMode)
  Owners(List(#(process.Pid, Bool)))
  Users(Int)
  Items(Int)
  Status(InfoLogStatus)
  Node(atom.Atom)
  Head(InfoLogHead)
  NoWrittenItems(Int)
  Full(Bool)
  NoCurrentBytes(Int)
  NoCurrentItems(Int)
  NoItems(Int)
  CurrentFile(Int)
  NoOverflows(since_log_was_opened: Int, since_last_info: Int)
}

/// Usado em DiskLogInfo
pub type InfoLogHead {
  InfoHead(Option(Dynamic))
  // erlang type MFA
  InfoHeadFun(#(atom.Atom, atom.Atom, List(Dynamic)))
}

/// Usado em DiskLogInfo
pub type InfoLogStatus {
  Ok
  Blocked(Bool)
}
