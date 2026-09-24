////
//// GBR: Erlang Disk Log Test Module
////

import gleam/dynamic
import gleam/dynamic/decode.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/int
import gleam/list
import gleam/option.{None}
import gleeunit/should

import gleeunit
import simplifile

import gbr/disk_log/info
import gbr/disk_log/options
import gbr/gdisk_log

// gleeunit start tests
pub fn main() -> Nil {
  gleeunit.main()
}

/// test options builder
pub fn options_builder_test() {
  let _ =
    gdisk_log.new("test")
    |> gdisk_log.with_file("test.log")
    |> gdisk_log.with_type(options.Wrap)
    |> gdisk_log.with_format(options.Internal)
    |> gdisk_log.with_size(options.MaxNoBytes(1024, 5))
    |> gdisk_log.with_mode(options.ReadWrite)
    |> gdisk_log.with_repair(True)
    |> gdisk_log.with_notify(True)
    |> gdisk_log.with_quiet(True)
}

/// test invalid path
pub fn invalid_path_test() {
  let test_log_name = "invalid_path_log"
  let test_log_path = "/this/path/should/not/exist/ever"

  let options =
    gdisk_log.new(test_log_name)
    |> gdisk_log.with_file(test_log_path)

  gdisk_log.open(options)
  |> should.be_error()
}

pub fn disk_log_options_test() {
  let test_log_name = "test_open"
  let test_log_path = "./priv/test_open.log"
  let test_atom = atom.create(test_log_name)
  let test_charlist = charlist.from_string("./priv/test_open.log")

  gdisk_log.new(test_log_name)
  |> gdisk_log.with_file(test_log_path)
  |> gdisk_log.with_format(options.External)
  |> gdisk_log.with_mode(options.ReadOnly)
  |> gdisk_log.with_notify(True)
  |> gdisk_log.with_quiet(True)
  |> gdisk_log.with_repair(True)
  |> gdisk_log.with_size(options.Infinity)
  |> gdisk_log.with_type(options.Halt)
  |> gdisk_log.to_dynamic_options()
  |> ffi_from_dynamic()
  |> should.equal([
    Name(test_atom),
    File(test_charlist),
    Repair(True),
    Type(options.Halt),
    Format(options.External),
    Size(options.Infinity),
    Notify(True),
    Mode(options.ReadOnly),
    Quiet(True),
  ])
}

@external(erlang, "gleam_stdlib", "identity")
fn ffi_from_dynamic(v: List(Dynamic)) -> a

type Info {
  Name(atom.Atom)
  File(charlist.Charlist)
  Repair(Bool)
  Type(options.LogType)
  Format(options.LogFormat)
  Size(options.LogSize)
  Notify(Bool)
  Quiet(Bool)
  Mode(options.LogMode)
}

pub fn open_return_test() {
  let test_log_name = "test_open"
  let test_log_path = "./priv/test_open.log"

  let options =
    gdisk_log.new(test_log_name)
    |> gdisk_log.with_file(test_log_path)

  let return =
    gdisk_log.open(options)
    |> should.be_ok()

  gdisk_log.from_open_return(return)
  |> gdisk_log.info()
  |> should.be_ok()

  gdisk_log.open_return_to_recovery(return)
  |> should.equal(0)

  gdisk_log.open_return_to_bad_bytes(return)
  |> should.equal(0)

  let _ = simplifile.delete_all([test_log_path])
}

pub fn disk_log_info_test() {
  let id = int.random(100_000) |> int.to_string()
  let test_log_name = "test_log_async_" <> id
  let test_log_path = "./priv/test_async_" <> id <> ".log"

  let _ = simplifile.create_directory_all("./priv")

  let options =
    gdisk_log.new(test_log_name)
    |> gdisk_log.with_file(test_log_path)
    |> gdisk_log.with_type(options.Halt)
    |> gdisk_log.with_format(options.Internal)
    |> gdisk_log.with_repair_truncate()

  // 1. Open
  let assert Ok(log) = gdisk_log.open_log(options)

  // 2. Info
  let infos =
    gdisk_log.info(log)
    |> should.be_ok()

  let _ = {
    use info <- list.map(infos)
    case info {
      info.Name(name) -> atom.to_string(name) |> should.equal(test_log_name)
      info.File(file) ->
        file
        |> charlist.to_string()
        |> should.equal(test_log_path)
      info.Type(type_) -> should.equal(type_, options.Halt)
      info.Format(format) -> should.equal(format, options.Internal)
      info.Size(size) -> should.equal(size, options.Infinity)
      info.Mode(mode) -> should.equal(mode, options.ReadWrite)
      info.Users(users) -> should.equal(users, 0)
      info.Status(status) -> should.equal(status, info.Ok)
      info.Node(node) -> should.equal(node, atom.create("nonode@nohost"))
      info.NoWrittenItems(items) -> should.equal(items, 0)
      info.Full(full) -> should.equal(full, False)
      info.Items(items) -> should.equal(items, 0)
      // TODO {head, {info_head, none}} -> {head, none}
      // info.Head(head) ->
      //   case head {
      //     info.InfoHead(head) -> should.equal(head, None)
      //     _ -> should.fail()
      //   }
      _ -> Nil
    }
  }

  let _ = simplifile.delete_all([test_log_path])
}

/// test async write log and sync
pub fn async_log_sync_test() {
  let id = int.random(100_000) |> int.to_string()
  let test_log_name = "test_log_async_" <> id
  let test_log_path = "./priv/test_async_" <> id <> ".log"

  let _ = simplifile.create_directory_all("./priv")

  let options =
    gdisk_log.new(test_log_name)
    |> gdisk_log.with_file(test_log_path)
    |> gdisk_log.with_type(options.Halt)
    |> gdisk_log.with_format(options.Internal)
    |> gdisk_log.with_repair_truncate()

  // 1. Open
  let assert Ok(log) = gdisk_log.open_log(options)

  // 2. Async Log
  let assert Ok(_) =
    gdisk_log.log_async(log, dynamic.bit_array(<<"async_data">>))

  // 3. Sync
  let assert Ok(_) = gdisk_log.sync(log)

  // 4. Close
  gdisk_log.close(log)
  |> should.be_ok()

  let _ = simplifile.delete_all([test_log_path])
}

pub fn sync_log_and_chunk_test_x() {
  let id = int.random(100_000) |> int.to_string()
  let test_log_name = "test_log_sync_" <> id
  let test_log_path = "./priv/test_sync_" <> id <> ".log"

  let _ = simplifile.create_directory_all("./priv")

  let options =
    gdisk_log.new(test_log_name)
    |> gdisk_log.with_file(test_log_path)
    |> gdisk_log.with_type(options.Halt)
    |> gdisk_log.with_format(options.Internal)
    |> gdisk_log.with_repair_truncate()

  // 1. Open
  let assert Ok(log) = gdisk_log.open_log(options)

  // 2. Log
  let assert Ok(_) = gdisk_log.log(log, dynamic.bit_array(<<"sync_data">>))

  // 3. Chunk
  let assert Ok(data) =
    gdisk_log.chunk(log, gdisk_log.start_continuation(), None)
  let assert [binary] = gdisk_log.chunk_to_data(data)
  let assert Ok(binary) = decode.run(binary, decode.bit_array)
  let assert <<"sync_data">> = binary

  // 4. Close
  gdisk_log.close(log)
  |> should.be_ok()

  let _ = simplifile.delete_all([test_log_path])
}
