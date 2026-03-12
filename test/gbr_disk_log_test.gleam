import gbr/disk_log
import gleam/int
import gleeunit
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn async_log_sync_test() {
  let id = int.random(100_000) |> int.to_string()
  let test_log_name = "test_log_async_" <> id
  let test_log_path = "./priv/test_async_" <> id <> ".log"

  let _ = simplifile.create_directory_all("./priv")

  let log_disk = disk_log.new(test_log_name)
  let options =
    disk_log.options_empty
    |> disk_log.file(test_log_path)
    |> disk_log.type_(disk_log.Halt)
    |> disk_log.format(disk_log.Internal)
    |> disk_log.repair(disk_log.Truncate)

  // 1. Open
  let assert Ok(log) = disk_log.open_options(log_disk, options)

  // 2. Async Log
  let assert Ok(_) = disk_log.async_log(log, <<"async_data">>)

  // 3. Sync
  let assert Ok(_) = disk_log.sync(log)

  // 4. Close
  let assert Ok(_) = disk_log.close(log)

  let _ = simplifile.delete_all([test_log_path])
}
