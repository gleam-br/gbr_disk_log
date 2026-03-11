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

import gbr/disk_log/core
import gleam/result

/// A handle to a disk log.
pub type LogDisk =
  core.LogDisk

/// Possible errors returned by disk log operations.
pub type DiskLogError =
  core.DiskLogError

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
pub type LogMode =
  core.LogMode

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
pub type LogOpts =
  core.LogOpts

/// A continuation for chunked reading of log data.
pub type Continuation =
  core.Continuation

/// Data returned from a chunked read operation.
pub type ChunkData {
  /// End of file reached.
  Eof
  /// A chunk of data with its continuation.
  Chunk(continuation: Continuation, terms: List(BitArray))
}

/// Detailed information about a disk log.
pub type LogInfo =
  core.LogInfo

/// Empty configuration options.
pub const opts_empty = core.opts_empty

/// Create a new LogDisk instance from a name.
///
/// ```gleam
/// let log = disk_log.new("my_log")
/// ```
pub fn new(name: String) -> LogDisk {
  core.new(name)
}

/// Set the file path for the log.
pub fn file(opts: LogOpts, path: String) -> LogOpts {
  core.file(opts, path)
}

/// Set the log type.
pub fn type_(opts: LogOpts, t: LogType) -> LogOpts {
  let core_t = case t {
    Halt -> core.Halt
    Wrap -> core.Wrap
    Rotate -> core.Rotate
  }
  core.type_(opts, core_t)
}

/// Set the log size.
pub fn size(opts: LogOpts, s: LogSize) -> LogOpts {
  let core_s = case s {
    Infinity -> core.Infinity
    MaxBytes(b) -> core.MaxBytes(b)
    WrapSize(b, f) -> core.WrapSize(b, f)
  }
  core.size(opts, core_s)
}

/// Set the log format.
pub fn format(opts: LogOpts, f: LogFormat) -> LogOpts {
  let core_f = case f {
    Internal -> core.Internal
    External -> core.External
  }
  core.format(opts, core_f)
}

/// Set the repair strategy.
pub fn repair(opts: LogOpts, r: LogRepair) -> LogOpts {
  let core_r = case r {
    Enable -> core.Enable
    Truncate -> core.Truncate
    Disabled -> core.Disabled
  }
  core.repair(opts, core_r)
}

/// Open a disk log with default options.
///
/// If the log is already open, it returns the existing handle.
pub fn open(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  core.open(log)
}

/// Open a disk log with specific options.
pub fn open_opts(log: LogDisk, opts: LogOpts) -> Result(LogDisk, DiskLogError) {
  core.open_opts(log, opts)
}

/// Close a disk log.
pub fn close(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  core.close(log)
}

/// Log data to a disk log synchronously.
///
/// This function waits until the data is written to disk (or the OS buffers).
pub fn log(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  core.log(log, data)
}

/// Log data to a disk log asynchronously.
///
/// This function returns immediately after sending the data to the log process.
pub fn alog(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  core.alog(log, data)
}

/// Log binary data to a disk log asynchronously.
///
/// Similar to `alog`, but optimized for binary data.
pub fn balog(log: LogDisk, data: BitArray) -> Result(LogDisk, DiskLogError) {
  core.balog(log, data)
}

/// Synchronize the log buffers to disk.
pub fn sync(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  core.sync(log)
}

/// Read a chunk of data from the log starting at the given continuation.
///
/// Use `start_continuation()` to begin reading from the start of the log.
pub fn chunk(
  log: LogDisk,
  cont: Continuation,
) -> Result(ChunkData, DiskLogError) {
  core.chunk(log, cont)
  |> result.map(fn(data) {
    case data {
      core.Eof -> Eof
      core.Chunk(c, t) -> Chunk(c, t)
    }
  })
}

/// Block a log for maintenance.
///
/// When blocked, no new entries can be logged until `unblock` is called.
/// If `queue` is true, logging requests are queued.
pub fn block(log: LogDisk, queue: Bool) -> Result(LogDisk, DiskLogError) {
  core.block(log, queue)
}

/// Unblock a previously blocked log.
pub fn unblock(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  core.unblock(log)
}

/// Force a wrap log to move to the next file in the sequence.
pub fn inc_wrap_file(log: LogDisk) -> Result(LogDisk, DiskLogError) {
  core.inc_wrap_file(log)
}

/// Get detailed information about the log state.
pub fn info(log: LogDisk) -> Result(LogInfo, DiskLogError) {
  core.info(log)
}

/// Get the initial continuation for reading from the beginning of the log.
pub fn start_continuation() -> Continuation {
  core.start_continuation()
}
