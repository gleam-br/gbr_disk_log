# 📔 ROADMAP: High Reliability Log (gbr_disk_log)

## Vision

*Type-Safe* wrapper of the Erlang/OTP `disk_log` for persistence on the Edge and telecommunications-class Ring Buffers. Focused on extreme performance, type safety, and resilience to power failures.

---

## 🚀 Phase 1: Synchronous Core (Completed ✅)
*Focus: Implementation of the typed database and fundamental operations.*

- [x] **Strong Typing:** Mapping of `LogType`, `LogRepair`, `LogMode`, and `LogSize`.
- [x] **Base Operations:** `open`, `open_opts`, `close`, `log` (synchronous).
- [x] **Persistence:** `sync` to guarantee physical writes to disk.
- [x] **Reading:** `chunk` and `start_continuation` for efficient iteration over the data.
- [x] **Face Architecture:** Clean public API in `gbr/disk_log`.

---

## 🛠️ Phase 2: Full Parity (In Planning)
*Focus: Achieve parity with the advanced features of the native Erlang module.*

- [ ] **Asynchronous Modes:** Implement `alog/2` (asynchronous) and `balog/2` (binary asynchronous) for massive throughput.
- [ ] **Concurrency Control:** Add `block/1` and `unblock/1` for exclusive maintenance operations.
- [ ] **State Inspection:** Implement `info/1` to expose internal log metrics (current size, files, etc.).
- [ ] **Manual Rotation:** Implement `inc_wrap_file/1` to force file changes in `wrap` type logs.
- [ ] **Advanced Repair:** Improve handling of `{repaired, ...}` returns to expose recovery metrics.
