import gbr/disk_log/core
import simplifile

const const_core_test_name = "core_test_v5"

const const_core_test_path = "./priv/core-test-v5.log"

pub fn core_open_opts_test() {
  let _ = simplifile.create_directory_all("./priv")
  let _ = core.close(core.new(const_core_test_name))
  let log = core.new(const_core_test_name)

  let opts =
    core.opts_empty
    |> core.file(const_core_test_path)
    |> core.repair(core.Truncate)

  let assert Ok(log) = core.open_opts(log, opts)

  let assert Ok(log) = core.log(log, <<"hello">>)

  let assert Ok(_) = core.close(log)
}

pub fn core_close_opts_test() {
  let log = core.new(const_core_test_name)
  let _ = core.close(log)
}
