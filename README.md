# Gleam BR: Erlang Disk Log

[![Hex.pm](https://img.shields.io/hexpm/v/gbr_disk_log.svg)](https://hex.pm/packages/gbr_disk_log)
[![HexDocs](https://img.shields.io/badge/hex-docs-ffaff3.svg)](https://hexdocs.pm/gbr_disk_log/)

A Type-Safe Gleam wrapper for the robust Erlang `disk_log` module. Designed for Telecom-grade Ring Buffers, high-performance event persistence, and extreme telemetry scenarios.

## Overview

`gbr_disk_log` provides an idiomatic Gleam interface to Erlang's built-in disk logging utility. It allows for efficient logging of binary data to disk with various rotation and repair strategies, ensuring that your application's telemetry and event logs are handled with the same reliability as a Tier-1 telecom system.

## Why use?

- **Type Safety:** Leverage Gleam's strong type system to avoid common pitfalls when working with Erlang's `disk_log`.
- **OOM Prevention:** Written directly to disk, preventing memory overflow in high-throughput scenarios.
- **Async Operations:** Supports both synchronous (`log`) and asynchronous (`alog`, `balog`) logging for maximum performance.
- **Fault Tolerance:** Built on top of Erlang/OTP, benefiting from decades of battle-tested reliability.
- **Zero Dependencies:** Only depends on the Gleam standard library and Erlang/OTP.

## Installation

```sh
gleam add gbr_disk_log
```

## Quickstart

```gleam
import gbr/disk_log
import gleam/io

pub fn main() {
  // Configure and open a log
  let assert Ok(log) =
    disk_log.new("my_app_events")
    |> disk_log.file("events.log")
    |> disk_log.type_(disk_log.Halt)
    |> disk_log.format(disk_log.External)
    |> disk_log.open()

  // Log some data synchronously
  let assert Ok(_) = disk_log.log(log, <<"Hello, World!":utf8>>)

  // Log some data asynchronously
  let assert Ok(_) = disk_log.alog(log, <<"Async event":utf8>>)

  // Sync data to disk
  let assert Ok(_) = disk_log.sync(log)

  // Get info about the log
  let assert Ok(info) = disk_log.info(log)
  io.println("Log file: " <> info.file)

  // Close the log
  let assert Ok(_) = disk_log.close(log)
}
```

## Ecosystem

This package is part of the foundation of **Freunde Von Ideen (FVideen)** and the **gleam.dev.br** ecosystem, focused on building high-performance, reliable P2P and edge computing solutions.
