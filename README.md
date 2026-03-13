# 💽 Gleam BR: Erlang Disk Log

[![Hex.pm](https://img.shields.io/hexpm/v/gbr_disk_log.svg)](https://hex.pm/packages/gbr_disk_log)
[![HexDocs](https://img.shields.io/badge/hex-docs-ffaff3.svg)](https://hexdocs.pm/gbr_disk_log/)

Um wrapper Gleam com segurança de tipos para o robusto módulo `disk_log` do Erlang. Projetado para buffers circulares de nível de telecomunicações, persistência de eventos de alto desempenho e cenários de telemetria extrema.

## Overview

`gbr_disk_log` fornece uma interface Gleam idiomática para o utilitário de registro em disco integrado do Erlang. Ele permite o registro eficiente de dados binários em disco com várias estratégias de rotação e reparo, garantindo que os logs de telemetria e eventos do seu aplicativo sejam tratados com a mesma confiabilidade de um sistema de telecomunicações de nível 1.

## Quando usar? (Exemplos Práticos)

O `disk_log` do Erlang foi originalmente projetado pela Ericsson para sistemas de telecomunicações, para armazenar grandes quantidades de Registros de Detalhes de Chamadas (CDRs) sem travar os nós ou preencher indefinidamente os discos rígidos. No ecossistema Gleam, ele se destaca em cenários como:

* **Telemetria Limitada e IoT:** Armazenamento de milhares de leituras de sensores de alta frequência ou eventos de auditoria por segundo. Ao usar o modo `Wrap` (buffer circular), você garante que o log nunca excederá um limite específico de megabytes no seu disco.

* **Recuperação de Estado do Ator (WAL):** Implementação de um Log de Gravação Antecipada (WAR). Antes que um ator crucial altere seu estado (por exemplo, processando uma transação financeira), ele grava a intenção de forma assíncrona no `disk_log`. Se o servidor perder energia, o ator lê os blocos após a reinicialização para recuperar seu estado.
* **Prevenção de OOM:** Alivia a pressão sobre a memória. Se um sistema estiver sobrecarregado, em vez de manter milhões de mensagens na RAM (caixas de correio do ator), elas são gravadas em disco com segurança.

## Por que usar?

- **Segurança de Tipos:** Aproveite o sistema de tipos robusto do Gleam para evitar problemas comuns ao trabalhar com o `disk_log` do Erlang.

- **Prevenção de OOM:** Gravado diretamente em disco, evitando estouro de memória em cenários de alta taxa de transferência.

- **Operações Assíncronas:** Suporta registro síncrono (`log`) e assíncrono (`async_log`, `binary_async_log`) para máximo desempenho.
- **Tolerância a Falhas:** Construído sobre Erlang/OTP, beneficiando-se de décadas de confiabilidade comprovada em batalha.
- **Zero Dependências:** Depende apenas da biblioteca padrão do Gleam e do Erlang/OTP.

## Limitações (Quando NÃO usar)

Transparência é fundamental. `gbr_disk_log` é uma ferramenta altamente especializada, não uma solução mágica:
* **Não é um Logger Legível por Humanos:** Ele foi projetado para armazenar binários e termos Erlang de forma eficiente, não texto simples. Você não pode simplesmente usar `tail -f` em um log de encapsulamento no seu terminal; você precisa lê-lo programaticamente usando a função `chunk`. (Se você quiser um registro de log padrão no terminal, use os loggers `gleam_erlang` ou `wisp`).

* **Não é um Broker de Mensagens:** Não substitui o Kafka, RabbitMQ ou NATS. Ele não possui grupos de consumidores, roteamento pub/sub distribuído e rastreamento de offsets.
* **Somente para um único nó:** Grava no sistema de arquivos local. Não é um banco de dados distribuído. Se o disco físico for destruído, os dados serão perdidos, a menos que sejam replicados por outro sistema.

## Instalação

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
