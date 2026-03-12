# 💽 Gleam BR: Erlang Disk Log

[![Hex.pm](https://img.shields.io/hexpm/v/gbr_disk_log.svg)](https://hex.pm/packages/gbr_disk_log)
[![HexDocs](https://img.shields.io/badge/hex-docs-ffaff3.svg)](https://hexdocs.pm/gbr_disk_log/)

A Type-Safe Gleam wrapper for the robust Erlang `disk_log` module. Designed for Telecom-grade Ring Buffers, high-performance event persistence, and extreme telemetry scenarios.

## Overview

`gbr_disk_log` provides an idiomatic Gleam interface to Erlang's built-in disk logging utility. It allows for efficient logging of binary data to disk with various rotation and repair strategies, ensuring that your application's telemetry and event logs are handled with the same reliability as a Tier-1 telecom system.

## When to use it? (Practical Examples)

Erlang's `disk_log` was originally designed by Ericsson for Telecom systems to store massive amounts of Call Detail Records (CDRs) without crashing the nodes or indefinitely filling up the hard drives. In the Gleam ecosystem, it shines in scenarios such as:

* **Bounded Telemetry & IoT:** Storing thousands of high-frequency sensor readings or audit events per second. By using the `Wrap` (ring buffer) mode, you guarantee the log will never exceed a specific megabyte limit on your disk.
* **Actor State Recovery (WAL):** Implementing a Write-Ahead Log. Before a crucial actor mutates its state (e.g., processing a financial transaction), it asynchronously writes the intent to the `disk_log`. If the server loses power, the actor reads the chunks upon reboot to recover its state.
* **OOM Prevention:** Relieving memory pressure. If a system is overwhelmed, instead of holding millions of messages in RAM (actor mailboxes), flush them to disk safely.

## Why use?

- **Type Safety:** Leverage Gleam's strong type system to avoid common pitfalls when working with Erlang's `disk_log`.
- **OOM Prevention:** Written directly to disk, preventing memory overflow in high-throughput scenarios.
- **Async Operations:** Supports both synchronous (`log`) and asynchronous (`async_log`, `binary_async_log`) logging for maximum performance.
- **Fault Tolerance:** Built on top of Erlang/OTP, benefiting from decades of battle-tested reliability.
- **Zero Dependencies:** Only depends on the Gleam standard library and Erlang/OTP.

## Limitations (When NOT to use it)

Transparency is key. `gbr_disk_log` is a highly specialized tool, not a silver bullet:
* **Not a Human-Readable Logger:** It is designed to store binaries and Erlang terms efficiently, not plain text. You cannot easily `tail -f` a wrap log in your terminal; you must read it programmatically using the `chunk` function. (If you want standard terminal logging, use `gleam_erlang` or `wisp` loggers).
* **Not a Message Broker:** It is not a replacement for Kafka, RabbitMQ, or NATS. It lacks consumer groups, distributed pub/sub routing, and offset tracking.
* **Single-Node Only:** It writes to the local file system. It is not a distributed database. If the physical disk is destroyed, the data is lost unless replicated by another system.

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
  let options =
    disk_log.options_empty
    |> disk_log.file("events.log")
    |> disk_log.type_(disk_log.Halt)
    |> disk_log.format(disk_log.External)

  let assert Ok(log) =
    disk_log.new("my_app_events")
    |> disk_log.open_options(options)

  // Log some data synchronously
  let assert Ok(_) = disk_log.log(log, <<"Hello, World!":utf8>>)

  // Log some data asynchronously
  let assert Ok(_) = disk_log.async_log(log, <<"Async event":utf8>>)

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

This package is part of the foundation of **Gleam-BR** and the **gleam.dev.br** ecosystem, focused on building high-performance, reliable P2P and edge computing solutions.
