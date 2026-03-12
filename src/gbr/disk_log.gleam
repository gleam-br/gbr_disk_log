////
//// GBR Disk Log: A Type-Safe wrapper for Erlang's `disk_log`.
////
//// This module provides an idiomatic Gleam interface for creating and managing
//// disk logs. It supports various log types (halt, wrap, rotate), formats
//// (internal, external), and logging modes.
////
//// The `disk_log` module is part of Erlang's `kernel` application and is widely
//// used for building reliable, disk-backed logging systems that prevent
//// Out-Of-Memory (OOM) errors in high-throughput environments.
////
//// ## When to use it?
////
//// It is ideal for telemetry, audit logs, and actor state persistence where you
//// need a bounded disk footprint (ring buffers) without blocking actor
//// mailboxes or causing OOM.
////

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/charlist.{type Charlist}
import gleam/option.{type Option, None}
import gleam/result

/// A handle to a disk log.
pub opaque type LogDisk {
  LogDisk(name: Atom)
}

/// Possible errors returned by disk log operations.
pub type DiskLogError {
  DiskLogError(reason: String)
}

/// The strategy for repairing a log if it's found to be corrupted.
pub type LogRepair {
  /// Enable repair if needed.
  Enable
  /// Truncate the log if corrupted.
  Truncate
  /// Disable repair.
  Disabled
}

/// The format of the log data.
pub type LogFormat {
  /// Internal Erlang term format.
  Internal
  /// External binary format.
  External
}

/// The access mode for the log.
pub type LogMode {
  /// Open the log in read-only mode.
  ReadOnly
  /// Open the log in read-write mode.
  ReadWrite
}

/// The maximum size of the log.
pub type LogSize {
  /// No size limit.
  Infinity
  /// Maximum bytes for a single file.
  MaxBytes(Int)
  /// Maximum bytes and number of files for a wrap log.
  WrapSize(max_bytes: Int, max_files: Int)
}

/// The type of log to create.
pub type LogType {
  /// A single file log.
  Halt
  /// A sequence of wrap files.
  Wrap
  /// A sequence of rotate files (only external format).
  Rotate
}

/// Configuration options for opening a disk log.
pub opaque type LogOptions {
  LogOptions(
    file: Option(String),
    repair: Option(LogRepair),
    type_: Option(LogType),
    format: Option(LogFormat),
    size: Option(LogSize),
    notify: Option(Bool),
    head: Option(Dynamic),
    head_func: Option(Mfa),
    mode: Option(LogMode),
    quiet: Option(Bool),
  )
}

/// A module, function, and arguments tuple for callback functions.
type Mfa =
  #(Atom, Atom, List(Dynamic))

/// A continuation for chunked reading of log data.
pub type Continuation {
  Continuation(Dynamic)
}

/// Data returned from a chunked read operation.
pub type ChunkData {
  /// End of file reached.
  Eof
  /// A chunk of data with its continuation.
  Chunk(continuation: Continuation, terms: List(BitArray))
}

/// Detailed information about a disk log.
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

/// Empty configuration options.
pub const options_empty = LogOptions(
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

/// Create a new LogDisk instance from a name.
///
/// ```gleam
/// let log = disk_log.new("my_log")
/// ```
pub fn new(name: String) -> LogDisk {
  name
  |> atom.create()
  |> LogDisk()
}

/// Set the file path for the log.
pub fn file(options: LogOptions, path: String) -> LogOptions {
  LogOptions(..options, file: option.Some(path))
}

/// Set the log type.
pub fn type_(options: LogOptions, t: LogType) -> LogOptions {
  LogOptions(..options, type_: option.Some(t))
}

/// Set the log size.
pub fn size(options: LogOptions, s: LogSize) -> LogOptions {
  LogOptions(..options, size: option.Some(s))
}

/// Set the log format.
pub fn format(options: LogOptions, f: LogFormat) -> LogOptions {
  LogOptions(..options, format: option.Some(f))
}

/// Set the repair strategy.
pub fn repair(options: LogOptions, r: LogRepair) -> LogOptions {
  LogOptions(..options, repair: option.Some(r))
}

/// Open a disk log with default options.
///
/// If the log is already open, it returns the existing handle.
pub fn open(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  open_options(log, options_empty)
}

/// Open a disk log with specific options.
pub fn open_options(
  log: LogDisk,
  options: LogOptions,
) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_open(options)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Close a disk log.
pub fn close(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_close()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Log data to a disk log synchronously.
///
/// This function waits until the data is written to disk (or the OS buffers).
pub fn log(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_log(data)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Log data to a disk log asynchronously.
///
/// This function returns immediately after sending the data to the log process.
pub fn async_log(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_async_log(data)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Log binary data to a disk log asynchronously.
///
/// Similar to `async_log`, but optimized for binary data.
pub fn binary_async_log(
  log: LogDisk,
  data: BitArray,
) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_binary_async_log(data)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Synchronize the log buffers to disk.
pub fn sync(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_sync()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Read a chunk of data from the log starting at the given continuation.
///
/// Use `start_continuation()` to begin reading from the start of the log.
pub fn chunk(
  log: LogDisk,
  cont: Continuation,
) -> Result(ChunkData, DiskLogError) {
  log.name
  |> ffi_chunk(cont)
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Block a log for maintenance.
///
/// When blocked, no new entries can be logged until `unblock` is called.
/// If `queue` is true, logging requests are queued.
pub fn block(log: LogDisk, queue: Bool) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_block(queue)
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Unblock a previously blocked log.
pub fn unblock(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_unblock()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Force a wrap log to move to the next file in the sequence.
pub fn increment_wrap_file(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  log.name
  |> ffi_increment_wrap_file()
  |> result.map(fn(name) { LogDisk(name:) })
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Get detailed information about the log state.
pub fn info(log: LogDisk) -> Result(LogInfo, DiskLogError) {
  log.name
  |> ffi_info()
  |> result.map_error(fn(err) { DiskLogError(charlist.to_string(err)) })
}

/// Get the initial continuation for reading from the beginning of the log.
pub fn start_continuation() -> Continuation {
  ffi_start_continuation()
}

// PRIVATE
//

@external(erlang, "gbr_disk_log_ffi", "start_continuation")
fn ffi_start_continuation() -> Continuation

@external(erlang, "gbr_disk_log_ffi", "open")
fn ffi_open(name: Atom, options: LogOptions) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "close")
fn ffi_close(name: Atom) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "log")
fn ffi_log(name: Atom, data: BitArray) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "async_log")
fn ffi_async_log(name: Atom, data: BitArray) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "binary_async_log")
fn ffi_binary_async_log(name: Atom, data: BitArray) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "sync")
fn ffi_sync(name: Atom) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "chunk")
fn ffi_chunk(name: Atom, cont: Continuation) -> Result(ChunkData, Charlist)

@external(erlang, "gbr_disk_log_ffi", "block")
fn ffi_block(name: Atom, queue: Bool) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "unblock")
fn ffi_unblock(name: Atom) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "increment_wrap_file")
fn ffi_increment_wrap_file(name: Atom) -> Result(Atom, Charlist)

@external(erlang, "gbr_disk_log_ffi", "info")
fn ffi_info(name: Atom) -> Result(LogInfo, Charlist)
