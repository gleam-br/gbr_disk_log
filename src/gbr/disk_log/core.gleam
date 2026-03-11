////
//// `gbr/disk_log/core`: Core implementation for Erlang's `disk_log` wrapper.
////
//// This module handles the FFI (Foreign Function Interface) calls to Erlang's
//// `disk_log` and provides the opaque types for logs and options.
////
//// It is not intended to be used directly by most applications. Use the
//// `gbr/disk_log` facade instead for a more idiomatic experience and to
//// enable pattern matching on public types.
////

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/charlist.{type Charlist}
import gleam/option.{type Option, None}
import gleam/result

/// Opaque handle to a disk log process.
///
/// - name: Atom disk log instance.
///
/// https://www.erlang.org/doc/apps/kernel/disk_log.html
pub opaque type LogDisk {
  LogDisk(name: Atom)
}

/// Opaque configuration options for a disk log.
///
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#open/1
pub opaque type LogOpts {
  LogOpts(
    file: Option(String),
    repair: Option(LogRepair),
    type_: Option(LogType),
    format: Option(LogFormat),
    size: Option(LogSize),
    notify: Option(Bool),
    head: Option(Dynamic),
    head_func: Option(MFA),
    mode: Option(LogMode),
    quiet: Option(Bool),
  )
}

/// Supported log types for the disk log module.
pub type LogType {
  /// Halt logs write items to a single file.
  Halt
  /// Wrap logs use a sequence of files of limited size.
  Wrap
  /// Rotate logs rotate and compress files (external format only).
  Rotate
}

/// Strategies for repairing a disk log.
pub type LogRepair {
  /// Attempt to repair the log if corrupted.
  Enable
  /// Truncate the log if corruption is found.
  Truncate
  /// Do not attempt repair.
  Disabled
}

/// Possible formats for the log file data.
pub type LogFormat {
  /// Internal Erlang binary format.
  Internal
  /// External raw binary format.
  External
}

/// The access mode for the log file.
pub type LogMode {
  /// Open the log in read-only mode.
  ReadOnly
  /// Open the log in read-write mode.
  ReadWrite
}

/// A module, function, and arguments tuple for callback functions.
pub type MFA =
  #(Atom, Atom, List(Dynamic))

/// Maximum allowed size for a disk log.
pub type LogSize {
  /// No size limit.
  Infinity
  /// Limit by total bytes for a single file.
  MaxBytes(Int)
  /// Limit by total bytes and total number of files for wrap logs.
  WrapSize(max_bytes: Int, max_files: Int)
}

/// Error type for disk log operations.
pub type DiskLogError {
  /// A general error with a descriptive reason.
  DiskLogError(reason: String)
}

/// Opaque continuation used for reading chunks from the log.
pub type Continuation {
  Continuation(Dynamic)
}

/// Data structure for reading chunks of terms from the log.
pub type ChunkData {
  /// End of log file reached.
  Eof
  /// A chunk of log terms and the next continuation.
  Chunk(continuation: Continuation, terms: List(BitArray))
}

/// Current information about a log.
pub type LogInfo {
  LogInfo(
    name: String,
    file: String,
    type_: LogType,
    format: LogFormat,
    size: LogSize,
    mode: LogMode,
  )
}

/// Default empty options.
pub const opts_empty = LogOpts(
  file: None,
  repair: None,
  type_: None,
  format: None,
  size: None,
  notify: None,
  head: None,
  head_func: None,
  mode: None,
  quiet: None,
)

/// Create a new `LogDisk` handle from a name.
pub fn new(name: String) -> LogDisk {
  name
  |> atom.create()
  |> LogDisk()
}

/// Set the file path in the options.
pub fn file(opts: LogOpts, file: String) -> LogOpts {
  LogOpts(..opts, file: option.Some(file))
}

/// Set the repair strategy in the options.
pub fn repair(opts: LogOpts, repair: LogRepair) -> LogOpts {
  LogOpts(..opts, repair: option.Some(repair))
}

/// Set the log type in the options.
pub fn type_(opts: LogOpts, type_: LogType) -> LogOpts {
  LogOpts(..opts, type_: option.Some(type_))
}

/// Set the log size in the options.
pub fn size(opts: LogOpts, size: LogSize) -> LogOpts {
  LogOpts(..opts, size: option.Some(size))
}

/// Set the log format in the options.
pub fn format(opts: LogOpts, format: LogFormat) -> LogOpts {
  LogOpts(..opts, format: option.Some(format))
}

/// Open a log with default options.
pub fn open(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  open_opts(log, opts_empty)
}

/// Open a log with specific options.
pub fn open_opts(log: LogDisk, opts: LogOpts) -> Result(LogDisk, DiskLogError) {
  log.name
  |> open_ffi(opts)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Close a log.
pub fn close(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> close_ffi()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Log data synchronously.
pub fn log(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  log.name
  |> log_ffi(data)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Log data asynchronously.
pub fn alog(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  log.name
  |> alog_ffi(data)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Log binary data asynchronously.
pub fn balog(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  log.name
  |> balog_ffi(data)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Force sync log data to disk.
pub fn sync(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> sync_ffi()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Read a chunk of data from the log.
pub fn chunk(
  log: LogDisk,
  cont: Continuation,
) -> Result(ChunkData, DiskLogError) {
  log.name
  |> chunk_ffi(cont)
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Block a log process.
pub fn block(log: LogDisk, queue: Bool) -> Result(LogDisk, DiskLogError) {
  log.name
  |> block_ffi(queue)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Unblock a log process.
pub fn unblock(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> unblock_ffi()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Increment the wrap file counter.
pub fn inc_wrap_file(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> inc_wrap_file_ffi()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Get info about the log.
pub fn info(log: LogDisk) -> Result(LogInfo, DiskLogError) {
  log.name
  |> info_ffi()
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Get the initial continuation.
@external(erlang, "core_ffi", "start_continuation")
pub fn start_continuation() -> Continuation

/// Internal FFI for disk_log:open
@external(erlang, "core_ffi", "open")
fn open_ffi(name: Atom, args: LogOpts) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:close
@external(erlang, "core_ffi", "close")
fn close_ffi(name: Atom) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:log
@external(erlang, "core_ffi", "log")
fn log_ffi(name: Atom, data: BitArray) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:alog
@external(erlang, "core_ffi", "alog")
fn alog_ffi(name: Atom, data: BitArray) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:balog
@external(erlang, "core_ffi", "balog")
fn balog_ffi(name: Atom, data: BitArray) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:sync
@external(erlang, "core_ffi", "sync")
fn sync_ffi(name: Atom) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:chunk
@external(erlang, "core_ffi", "chunk")
fn chunk_ffi(name: Atom, cont: Continuation) -> Result(ChunkData, Charlist)

/// Internal FFI for disk_log:block
@external(erlang, "core_ffi", "block")
fn block_ffi(name: Atom, queue: Bool) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:unblock
@external(erlang, "core_ffi", "unblock")
fn unblock_ffi(name: Atom) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:inc_wrap_file
@external(erlang, "core_ffi", "inc_wrap_file")
fn inc_wrap_file_ffi(name: Atom) -> Result(Atom, Charlist)

/// Internal FFI for disk_log:info
@external(erlang, "core_ffi", "info")
fn info_ffi(name: Atom) -> Result(LogInfo, Charlist)
