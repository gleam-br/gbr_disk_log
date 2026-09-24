////
//// 💽 GBR Disk Log: A Type-Safe wrapper for Erlang's `disk_log`.
////
//// - Ref. https://www.erlang.org/doc/apps/kernel/disk_log.html
////
//// Este módulo fornece uma interface Gleam idiomática para criar e gerenciar
//// logs em disco. Ele suporta vários tipos de log (parada, enrolamento,
//// rotação), formatos (interno, externo) e modos de registro.
////
//// O módulo `disk_log` faz parte do aplicativo `kernel` do Erlang e é
//// amplamente usado para construir sistemas de registro confiáveis, baseados
//// em disco, que evitam erros de falta de memória (OOM) em ambientes de alto
//// desempenho.
////
//// ## Quando usá-lo?
////
//// É ideal para telemetria, logs de auditoria e persistência de estado de
//// atores, onde você precisa de uma pegada de disco limitada (buffers
//// circulares) sem bloquear as caixas de correio dos atores ou causar erros de
//// falta de memória.
////
//// O que é este módulo?
////
//// Um wrapper Gleam com segurança de tipos para o robusto módulo `disk_log` do
//// Erlang. Projetado para buffers circulares de nível de telecomunicações,
//// persistência de eventos de alto desempenho e cenários de telemetria extrema.
////
//// ## Overview
////
//// Estou módulo fornece uma interface Gleam idiomática para o utilitário de
//// registro em disco integrado do Erlang. Ele permite o registro eficiente de
//// dados binários em disco com várias estratégias de rotação e reparo,
//// garantindo que os logs de telemetria e eventos do seu aplicativo sejam
//// tratados com a mesma confiabilidade de um sistema de telecomunicações de
//// nível 1.
////
//// ## Quando usar? (Exemplos Práticos)
////
//// O `disk_log` do Erlang foi originalmente projetado pela Ericsson para
//// sistemas de telecomunicações, para armazenar grandes quantidades de
//// Registros de Detalhes de Chamadas (CDRs) sem travar os nós ou preencher
//// indefinidamente os discos rígidos. No ecossistema Gleam, ele se destaca em
//// cenários como:
////
//// * **Telemetria Limitada e IoT:** Armazenamento de milhares de leituras de
//// sensores de alta frequência ou eventos de auditoria por segundo. Ao usar o
//// modo `Wrap` (buffer circular), você garante que o log nunca excederá um
//// limite específico de megabytes no seu disco.
////
//// * **Recuperação de Estado do Ator (WAL):** Implementação de um Log de
//// Gravação Antecipada (WAR). Antes que um ator crucial altere seu estado (por
//// exemplo, processando uma transação financeira), ele grava a intenção de forma
//// assíncrona no `disk_log`. Se o servidor perder energia, o ator lê os blocos
//// após a reinicialização para recuperar seu estado.
////
//// * **Prevenção de OOM:** Alivia a pressão sobre a memória. Se um sistema
//// estiver sobrecarregado, em vez de manter milhões de mensagens na RAM (caixas
//// de correio do ator), elas são gravadas em disco com segurança.
////
//// ## Por que usar?
////
//// - **Segurança de Tipos:** Aproveite o sistema de tipos robusto do Gleam para
//// evitar problemas comuns ao trabalhar com o `disk_log` do Erlang.
////
//// - **Prevenção de OOM:** Gravado diretamente em disco, evitando estouro de
//// memória em cenários de alta taxa de transferência.
////
//// - **Operações Assíncronas:** Suporta registro síncrono (`log`) e assíncrono
//// (`async_log`, `binary_async_log`) para máximo desempenho.
////
//// - **Tolerância a Falhas:** Construído sobre Erlang/OTP, beneficiando-se de
//// décadas de confiabilidade comprovada em batalha.
////
//// - **Zero Dependências:** Depende apenas da biblioteca padrão do Gleam e do
//// Erlang/OTP.
////
//// ## Limitações (Quando NÃO usar)
////
//// Transparência é fundamental. `disk_log` é uma ferramenta altamente
//// especializada, não uma solução mágica:
////
//// * **Não é um Logger Legível por Humanos:** Ele foi projetado para armazenar
//// binários e termos Erlang de forma eficiente, não texto simples. Você não
//// pode simplesmente usar `tail -f` em um log de encapsulamento no seu
//// terminal; você precisa lê-lo programaticamente usando a função `chunk`.
////
//// * **Não é um Broker de Mensagens:** Não substitui o Kafka, RabbitMQ ou NATS.
//// Ele não possui grupos de consumidores, roteamento pub/sub distribuído e
//// rastreamento de offsets.
////
//// * **Somente para um único nó:** Grava no sistema de arquivos local. Não é um
//// banco de dados distribuído. Se o disco físico for destruído, os dados serão
//// perdidos, a menos que sejam replicados por outro sistema.
////
//// ## Como usar?
////
//// ```gleam
//// import gbr/disk_log
//// import gleam/io
////
//// pub fn main() {
//// // Configure and open a log
//// let options =
////   disk_log.options_empty
////   |> disk_log.file("events.log")
////   |> disk_log.type_(disk_log.Halt)
////   |> disk_log.format(disk_log.External)
////
//// let assert Ok(log) =
////   disk_log.new("my_app_events")
////   |> disk_log.open_options(options)
////
//// // Log some data synchronously
//// let assert Ok(_) = disk_log.log(log, <<"Hello, World!":utf8>>)
////
//// // Log some data asynchronously
//// let assert Ok(_) = disk_log.async_log(log, <<"Async event":utf8>>)
////
//// // Sync data to disk
//// let assert Ok(_) = disk_log.sync(log)
////
//// // Get info about the log
//// let assert Ok(info) = disk_log.info(log)
//// io.println("Log file: " <> info.file)
////
//// // Close the log
//// let assert Ok(_) = disk_log.close(log)
////
////``
////
//// > Depende do FFI `gbr_disk_log_ffi.erl`
////

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import gbr/disk_log/info.{
  type DiskLogInfo, type InfoLogHead, InfoHead, InfoHeadFun,
}
import gbr/disk_log/options.{
  type LogFormat, type LogMode, type LogSize, type LogType,
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Open/Close
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#open/1
///
/// Abre um novo arquivo disk_log para leitura ou gravação.
///
/// O parâmetro é uma lista das seguintes opções:
///
/// - `{name, Log}`: Especifica o nome do log. Este nome deve ser passado como
/// parâmetro em todas as operações de registro subsequentes. Um nome deve sempre
/// ser fornecido.
/// - `{file, FileName}`: Especifica o nome do arquivo a ser usado para os termos
/// registrados. Se este valor for omitido e o nome do log for um átomo ou uma
/// string, o nome do arquivo será definido como lists:concat([Log, ".LOG"]) para
/// logs de parada.
/// - Para logs de encapsulamento, este é o nome base dos arquivos. Cada arquivo
/// em um log de encapsulamento é chamado <FileName>.N, onde N é um número inteiro.
/// Cada log de encapsulamento também possui dois arquivos chamados <FileName>.idx
/// e <FileName>.siz.
/// - Para logs de rotação, este é o nome do arquivo de log ativo. Os arquivos
/// compactados são nomeados como <FileName>.N.gz, onde N é um número inteiro e
/// <FileName>.0.gz é o arquivo de log compactado mais recente. Todos os
/// arquivos compactados são renomeados a cada rotação para que os arquivos mais
/// recentes tenham o menor índice. O valor máximo para N é o valor de
/// MaxNoFiles menos 1.
/// - `{linkto, LinkTo}`: Se LinkTo for um PID, ele se torna o proprietário do
/// log. Se LinkTo não for nenhum, o log registra que está sendo usado
/// anonimamente por algum processo, incrementando o contador de usuários. Por
/// padrão, o processo que chama open/1 é o proprietário do log.
/// - `{repair, Repair}`: Se Repair for verdadeiro, o arquivo de log atual será
/// reparado, se necessário. Conforme a restauração é iniciada, uma mensagem é
/// exibida no log de erros. Se falso for especificado, nenhuma tentativa de
/// reparo automático será feita. Em vez disso, a tupla `{error, {need_repair, Log}}`
/// é retornada se houver uma tentativa de abrir um arquivo de log corrompido.
/// Se truncate for especificado, o arquivo de log será truncado, criando um log
/// vazio, independentemente do conteúdo anterior. O padrão é verdadeiro, o que
/// não tem efeito sobre os logs abertos em modo somente leitura.
/// - `{type, Type}`: O tipo de log. O padrão é halt.
/// - `{format, Format}`: Formato do log em disco. O padrão é internal.
/// - `{size, Size}`: Tamanho do log. Quando um log de parada atinge seu tamanho
/// máximo, todas as tentativas de registrar mais itens são rejeitadas. O padrão
/// é infinito, o que para o log de parada implica que não há tamanho máximo.
/// Para logs de encapsulamento e rotação, o parâmetro Size pode ser um par
/// `{MaxNoBytes, MaxNoFiles}`. Para logs de encapsulamento, também pode ser
/// infinito. Neste último caso, se os arquivos de um log de encapsulamento
/// existente com o mesmo nome puderem ser encontrados, o tamanho será lido do
/// log de encapsulamento existente; caso contrário, um erro será retornado.
/// Os logs de encapsulamento gravam no máximo MaxNoBytes bytes em cada arquivo
/// e usam MaxNoFiles arquivos antes de recomeçar com o primeiro arquivo de log
/// de encapsulamento. Independentemente de MaxNoBytes, pelo menos o cabeçalho
/// (se houver) e um item são gravados em cada arquivo de log de encapsulamento
/// antes de passar para o próximo arquivo. Na primeira vez que um log de
/// encapsulamento existente é aberto, ou seja, quando o processo de log em
/// disco é criado, o valor da opção size pode ser diferente do tamanho atual do
/// log, e o tamanho do log em disco é alterado de acordo com change_size/2.
/// Ao abrir um log de encapsulamento existente, não é necessário fornecer um
/// valor para a opção size, mas se o log já estiver aberto, ou seja, se o
/// processo de log em disco existir, o valor fornecido deve ser igual ao tamanho
/// atual do log; caso contrário, a tupla `{error, {size_mismatch, CurrentSize, NewSize}}`
/// é retornada. A rotação de logs grava no máximo MaxNoBytes bytes no arquivo
/// de log ativo e mantém os MaxNoFiles arquivos compactados mais recentes.
/// Independentemente de MaxNoBytes, pelo menos o cabeçalho (se houver) e um
/// item são gravados em cada arquivo de log de rotação antes da rotação. Ao
/// abrir um log de parada já aberto, a opção `size` é ignorada.
/// - `{notify, boolean()}`: Se verdadeiro, os proprietários do log são
/// notificados quando determinados eventos de log ocorrem. O padrão é falso. Os
/// proprietários recebem uma das seguintes mensagens quando um evento ocorre:
///   - `{disk_log, Node, Log, {wrap, NoLostItems}}` Enviada quando um log de
/// encerramento preenche um de seus arquivos e um novo arquivo é aberto. `NoLostItems`
/// é o número de itens registrados anteriormente que foram perdidos ao truncar
/// os arquivos existentes.
///   - `{disk_log, Node, Log, {truncated, NoLostItems}}` Enviada quando um log é
/// truncado ou reaberto. Para logs de parada, `NoLostItems` é o número de itens
/// gravados no log desde a criação do processo de log de disco. Para logs de
/// encerramento, `NoLostItems` é o número de itens em todos os arquivos de log
/// de encerramento.
///   - `{disk_log, Node, Log, {read_only, Items}}` Enviado quando uma tentativa
/// de registro assíncrono é feita em um arquivo de log aberto em modo somente
/// leitura. `Items` são os itens da tentativa de registro.
///   - `{disk_log, Node, Log, {blocked_log, Items}}` Enviado quando uma
/// tentativa de registro assíncrono é feita em um log bloqueado que não
/// enfileira tentativas de registro. `Items` são os itens da tentativa de
/// registro.
///   - `{disk_log, Node, Log, {format_external, Items}}` Enviado quando a função
/// `alog/2` ou `alog_terms/2` é usada para logs formatados internamente. `Items`
/// são os itens da tentativa de registro.
///   - `{disk_log, Node, Log, full}` Enviado quando uma tentativa de registrar
/// itens em um log de encapsulamento (wrap log) gravaria mais bytes do que o
/// limite definido pela opção `size`.
///   - `{disk_log, Node, Log, {error_status, Status}}` Enviado quando o status de
/// erro muda. O status de erro é definido pelo resultado da última tentativa de
/// registrar itens no log, ou de truncar o log, ou pelo último uso da função
/// `sync/`1, `inc_wrap_file/1` ou `change_size/2`. O status é ok ou `{error, Error}`,
/// sendo o primeiro o valor inicial.
/// - `{head, Head}` Especifica um cabeçalho a ser gravado primeiro no arquivo
/// de log. Se o log for um log de enrolamento ou rotação, o item Head será gravado
/// primeiro em cada novo arquivo. Head deve ser um termo se o formato for interno;
/// caso contrário, será um iodata/0. O padrão é none, o que significa que nenhum
/// cabeçalho será gravado primeiro no arquivo.
/// - `{head_func, {M,F,A}}` Especifica uma função a ser chamada cada vez que um
/// novo arquivo de log for aberto. Assume-se que a chamada M:F(A) retorne `{ok, Head}`.
/// O item Head será gravado primeiro em cada arquivo. Head deve ser um termo se
/// o formato for interno; caso contrário, será um iodata/0.
/// - `{mode, Mode}` Especifica se o log deve ser aberto no modo somente leitura
/// ou leitura e gravação. O padrão é leitura/gravação.
/// - `{quiet, Boolean}` Especifica se as mensagens serão enviadas ao
/// `error_logger` em caso de erros recuperáveis ​​nos arquivos de log. O padrão é
/// falso.
///
/// **Retorno**
///
/// - `open/1` retorna `{ok, Log}` se o arquivo de log for aberto com sucesso.
/// Se o arquivo for reparado com sucesso, a tupla `{repaired, Log, {recovered,
/// Rec}, {badbytes, Bad}}` é retornada, onde Rec é o número de termos Erlang
/// completos encontrados no arquivo e Bad é o número de bytes no arquivo que
/// não são termos Erlang.
/// - Quando um log de disco é aberto no modo de leitura/gravação, verifica-se
/// se existe algum arquivo de log. Se não houver nenhum, um novo log vazio é
/// criado; caso contrário, o arquivo existente é aberto na posição após o
/// último item registrado e o registro de itens começa a partir daí. Se o
/// formato for interno e o arquivo existente não for reconhecido como um log
/// formatado internamente, uma tupla `{error, {not_a_log_file, FileName}}` será
/// retornada.
/// - `open/1` não pode ser usado para alterar os valores das opções de um log
/// aberto. Quando houver proprietários ou usuários anteriores de um log, todos
/// os valores das opções, exceto `name`, `linkto` e `notify`, serão verificados
/// apenas em relação aos valores fornecidos anteriormente como valores de opção
/// para as funções `open/1`, `change_header/2`, `change_notify/3` ou
/// `change_size/2`. Portanto, nenhuma das opções, exceto `name`, é obrigatória.
/// Se algum valor especificado for diferente do valor atual, uma tupla
/// `{error, {arg_mismatch, OptionName, CurrentValue, Value}}` será retornada.
pub fn open(options: Builder) -> Result(OpenReturn, String) {
  let options = to_dynamic_options(options)

  let response =
    ffi_disk_log_open(options)
    |> decode.run(to_open_return_decoder())

  case response {
    Ok(open_return) ->
      open_return
      |> error_to_string()
    Error(err) -> string.inspect(err) |> Error
  }
}

/// Mesmo que o open/1, mas retornando somente a ref. ao `DiskLog`.
pub fn open_log(options: Builder) -> Result(DiskLog, String) {
  open(options)
  |> result.map(from_open_return)
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#close/1
///
/// Fecha corretamente um log de disco.
///
/// Um log formatado internamente deve ser fechado antes que o sistema Erlang
/// seja interrompido. Caso contrário, o log é considerado aberto e o
/// procedimento de reparo automático é ativado na próxima vez que o log for
/// aberto.
///
/// O processo de log de disco não é encerrado enquanto houver proprietários
/// ou usuários do log. Todos os proprietários devem fechar o log,
/// possivelmente encerrando o processo. Além disso, qualquer outro processo,
/// não apenas os processos que abriram o log anonimamente, pode decrementar
/// o contador de usuários fechando o log. Tentativas de fechar um log por um
/// processo que não seja proprietário são ignoradas se não houver usuários.
///
/// Se o log estiver bloqueado pelo processo de fechamento, ele também será
/// desbloqueado.
pub fn close(log: DiskLog) -> Result(Nil, String) {
  ffi_disk_log_close(log.ref)
  |> result_normalize()
  |> error_to_string()
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- API
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#all/0
pub fn all() -> List(DiskLog) {
  ffi_disk_log_all()
  |> list.map(DiskLog)
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#alog_terms/2
pub fn log_async_terms(
  log: DiskLog,
  term_list: List(Dynamic),
) -> Result(Nil, String) {
  ffi_disk_log_alog_terms(log.ref, term_list)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#blog_terms/2
pub fn log_binary_terms(
  log: DiskLog,
  bytes_list: List(BitArray),
) -> Result(Nil, String) {
  ffi_disk_log_blog_terms(log.ref, bytes_list)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#balog_terms/2
pub fn log_async_binary_terms(log: DiskLog, bytes_list) {
  ffi_disk_log_balog_terms(log.ref, bytes_list)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#bchunk/2
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#bchunk/3
pub fn chunk_binary(
  log: DiskLog,
  continuation: Continuation,
  length: Option(Int),
) -> Result(ChunkData(BitArray), String) {
  let Continuation(continuation) = continuation

  use response <- result.try(
    case length {
      Some(length) -> ffi_disk_log_bchunk_length(log.ref, continuation, length)
      None -> ffi_disk_log_bchunk(log.ref, continuation)
    }
    |> result_normalize()
    |> error_to_string(),
  )

  decode.run(response, to_chunk_binary_decoder())
  |> result.map_error(string.inspect)
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#block/1
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#block/2
///
/// Bloqueia o log para manutenção.
///
/// Quando bloqueado, nenhuma entrada pode ser logada até `unblock` ser chamado.
/// Se `queue` é `true`, as requisições de escrita são enfileiradas.
pub fn block(log: DiskLog, queue_log_records: Option(Bool)) {
  case queue_log_records {
    Some(queue_log_records) ->
      ffi_disk_log_block_queue_log_rec(log.ref, queue_log_records)
    None -> ffi_disk_log_block(log.ref)
  }
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#breopen/3
pub fn reopen_binary(log: DiskLog, file, bhead) {
  ffi_disk_log_breopen(log.ref, file, bhead)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#btruncate/2
pub fn truncate_binary(log: DiskLog, bhead) {
  ffi_disk_log_btruncate(log.ref, bhead)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#change_header/2
pub fn change_header(log: DiskLog, header) -> Result(Nil, String) {
  ffi_disk_log_change_header(log.ref, header)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#change_notify/3
pub fn change_notify(
  log: DiskLog,
  owner: process.Pid,
  notify: Bool,
) -> Result(Nil, String) {
  ffi_disk_log_change_notify(log.ref, owner, notify)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#change_size/2
pub fn change_size(log: DiskLog, size: LogSize) -> Result(Nil, String) {
  let size = to_dynamic_log_size(size)

  ffi_disk_log_change_size(log.ref, size)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#chunk/2
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#chunk/3
///
/// Faz a leitura de um `chunk` de dados a partir do log iniciando em um dado
/// `continuation`.
///
/// Usar `start_continuation()` para inicar a leitura a partir do início do log.
pub fn chunk(
  log: DiskLog,
  continuation: Continuation,
  length: Option(Int),
) -> Result(ChunkData(Dynamic), String) {
  let Continuation(continuation) = continuation

  use response <- result.try(
    case length {
      None -> ffi_disk_log_chunk(log.ref, continuation)
      Some(length) -> ffi_disk_log_chunk_length(log.ref, continuation, length)
    }
    |> result_normalize()
    |> error_to_string(),
  )

  decode.run(response, to_chunk_dynamic_decoder())
  |> result.map_error(string.inspect)
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#chunk_info/1
pub fn chunk_info(
  continuation: Continuation,
) -> Result(List(atom.Atom), String) {
  let Continuation(continuation) = continuation

  ffi_disk_log_chunk_info(continuation)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#chunk_step/3
pub fn chunk_step(log: DiskLog, continuation: Continuation, step: Int) {
  let Continuation(continuation) = continuation

  ffi_disk_log_chunk_step(log.ref, continuation, step)
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#info/1
///
/// Recupera as informações detalhadas sobre o estado do log.
pub fn info(log: DiskLog) -> Result(List(DiskLogInfo), String) {
  ffi_disk_log_info(log.ref)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#log_terms/2
pub fn log_terms(log: DiskLog, term_list) {
  ffi_disk_log_log_terms(log.ref, term_list)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#next_file/1
///
/// Força um `wrap` log mover para o próximo arquivo da sequência.
pub fn next_file(log: DiskLog) -> Result(Nil, String) {
  ffi_disk_log_next_file(log.ref)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#pid2name/1
pub fn from_pid(pid: process.Pid) -> Result(Option(DiskLog), String) {
  ffi_disk_log_pid2name(pid)
  |> decode.run(to_log_or_undefined_decoder())
  |> result.map_error(string.inspect)
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#reopen/2
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#reopen/3
pub fn reopen(log: DiskLog, file: String, head: Option(Dynamic)) {
  let file = charlist.from_string(file)

  case head {
    Some(head) -> ffi_disk_log_reopen_head(log.ref, file, head)
    None -> ffi_disk_log_reopen(log.ref, file)
  }
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#sync/1
pub fn sync(log: DiskLog) -> Result(Nil, String) {
  ffi_disk_log_sync(log.ref)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#truncate/1
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#truncate/2
pub fn truncate(log: DiskLog, head: Option(Dynamic)) -> Result(Nil, String) {
  case head {
    None -> ffi_disk_log_truncate(log.ref)
    Some(head) -> ffi_disk_log_truncate_head(log.ref, head)
  }
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#unblock/1
pub fn unblock(log: DiskLog) -> Result(Nil, String) {
  ffi_disk_log_unblock(log.ref)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#log/2
///
/// Escreve os dados `term()` no log sincronamente.
///
/// Esta função espera até os dados serem escritos no disco (ou OS buffers).
pub fn log(log: DiskLog, data: Dynamic) -> Result(Nil, String) {
  ffi_disk_log_write(log.ref, data)
  |> result_normalize()
  |> error_to_string()
}

fn error_to_string(result: Result(a, Dynamic)) -> Result(a, String) {
  result
  |> result.map_error(ffi_disk_log_format_error)
  |> result.map_error(charlist.to_string)
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#alog/2
///
/// Escreve os dados term() no log assincronamente.
///
/// Esta função retorna imediatamente após enviar os dados para o processo (mailbox).
pub fn log_async(log: DiskLog, data: Dynamic) -> Result(Nil, String) {
  ffi_disk_log_write_async(log.ref, data)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#blog/2
///
/// Escreve dados binários assincronamente.
///
/// Similar ao `log`, mas otimizado para dados binários.
pub fn log_binary(log: DiskLog, data: BitArray) -> Result(Nil, String) {
  ffi_disk_log_write_binary(log.ref, data)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#balog/2
///
/// Escreve dados term() assincronamente.
///
/// Similar ao `async_log`, mas otimizado para dados binários.
pub fn log_async_binary(log: DiskLog, data: BitArray) -> Result(Nil, String) {
  ffi_disk_log_balog(log.ref, data)
  |> result_normalize()
  |> error_to_string()
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#balog/2
/// https://www.erlang.org/doc/apps/kernel/disk_log.html#balog/3
/// -type Continuation :: start | continuation()
///
/// **Obs:** O tipo erlang `continuation().` é opaco, portanto dinâmico.
///
/// Recupera um `continuation` inicial para leitura a partir do começo do log.
pub fn start_continuation() -> Continuation {
  get_atom("start")
  |> atom.to_dynamic()
  |> Continuation()
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -- Tipos
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/// A handle to a disk log.
pub opaque type DiskLog {
  DiskLog(ref: Dynamic)
}

/// Tipo p/ opções do log.
pub opaque type Builder {
  Builder(
    name: String,
    file: Option(charlist.Charlist),
    link_to: Option(process.Pid),
    repair: Option(atom.Atom),
    type_: Option(LogType),
    format: Option(LogFormat),
    size: Option(LogSize),
    notify: Option(Bool),
    mode: Option(LogMode),
    quiet: Option(Bool),
    head: Option(InfoLogHead),
  )
}

/// Um `continuation` p/ dados `chunked` de leitura do log.
pub opaque type Continuation {
  Continuation(Dynamic)
}

/// Dados retornados a partir de uma operação de leitura `chunk` ou `bchunk`.
pub opaque type ChunkData(a) {
  /// Fim dos dados (terms).
  Eof
  /// Um `chunk` (pedaço) do dado com seu `continuation`.
  ChunkData(continuation: Continuation, data: List(a), bad_bytes: Option(Int))
}

pub fn chunk_to_data(chunk: ChunkData(a)) -> List(a) {
  case chunk {
    Eof -> []
    ChunkData(_continuation, data, _bad_bytes) -> data
  }
}

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#t:open_ret/0
/// -type open_ret() ::
/// {ok, Log :: log()} |
/// {repaired,
///  Log :: log(),
///  {recovered, Rec :: non_neg_integer()},
///  {badbytes, Bad :: non_neg_integer()}} |
/// {error, open_error_rsn()}.
pub opaque type OpenReturn {
  OpenReturn(log: DiskLog)
  OpenRepaired(log: DiskLog, recovered: Int, bad_bytes: Int)
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Helpers
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/// Retorna a ref. ao `DiskLog` a partir do retorno da função `open`.
pub fn from_open_return(open: OpenReturn) -> DiskLog {
  case open {
    OpenReturn(log:) -> log
    OpenRepaired(log, _recovered, _bad_bytes) -> log
  }
}

/// Retorna a quantidadede bytes recuperados ao abrir o arquivo reparado.
pub fn open_return_to_recovery(open: OpenReturn) -> Int {
  case open {
    OpenReturn(_) -> 0
    OpenRepaired(_log, recovered, _bad_bytes) -> recovered
  }
}

/// Retorna a quantidade de bytes perdidos ao abrir o arquivo reparado.
pub fn open_return_to_bad_bytes(open: OpenReturn) -> Int {
  case open {
    OpenReturn(_) -> 0
    OpenRepaired(_log, _recovered, bad_bytes) -> bad_bytes
  }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Builder
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/// Cria novas opções padrão passando o nome do log.
pub fn new(name: String) -> Builder {
  Builder(
    name:,
    file: None,
    link_to: None,
    repair: None,
    type_: None,
    format: None,
    size: None,
    notify: None,
    mode: None,
    quiet: None,
    head: None,
  )
}

/// Incluir um arquivo específico de log, senão é usado o `name`.
pub fn with_file(options: Builder, file: String) -> Builder {
  let file = charlist.from_string(file)

  Builder(..options, file: Some(file))
}

/// Incluir o tipo de log.
pub fn with_type(options: Builder, type_: LogType) -> Builder {
  Builder(..options, type_: Some(type_))
}

/// Incluir o tamanho do log.
pub fn with_size(options: Builder, size: LogSize) -> Builder {
  Builder(..options, size: Some(size))
}

/// Incluir o format do log.
pub fn with_format(options: Builder, format: LogFormat) -> Builder {
  Builder(..options, format: Some(format))
}

/// Linkar outro processo como dono.
pub fn with_link_to(options: Builder, link_to: process.Pid) -> Builder {
  Builder(..options, link_to: Some(link_to))
}

/// Incluir a estratégia de reparo do log.
pub fn with_repair(options: Builder, repair: Bool) -> Builder {
  let repair = case repair {
    True -> get_atom_true()
    False -> get_atom_false()
  }

  Builder(..options, repair: Some(repair))
}

/// Incluir repair como `truncate`.
pub fn with_repair_truncate(options: Builder) -> Builder {
  Builder(..options, repair: Some(get_atom_truncate()))
}

/// Incluir se as notificações devem ser enviadas ao dono do disk_log.
pub fn with_notify(options: Builder, notify: Bool) -> Builder {
  Builder(..options, notify: Some(notify))
}

/// Incluir um cabeçalho no log.
pub fn with_head(options: Builder, head: Option(Dynamic)) -> Builder {
  Builder(..options, head: Some(InfoHead(head)))
}

/// Incluir um cabeçalho através de uma função (MFA).
///
/// Esta função é usada para gerar o cabeçalho p/ cada novo arquivo, **cuidado**.
pub fn with_head_func(
  options: Builder,
  module: atom.Atom,
  function: atom.Atom,
  args: List(Dynamic),
) -> Builder {
  let mfa = #(module, function, args)

  Builder(..options, head: Some(InfoHeadFun(mfa)))
}

/// Incluir o acesso do modo para o log.
pub fn with_mode(options: Builder, mode: LogMode) -> Builder {
  Builder(..options, mode: Some(mode))
}

/// Incluir se será silencio as operações, suprindo mensagens de erro para o terminal.
pub fn with_quiet(options: Builder, quiet: Bool) -> Builder {
  Builder(..options, quiet: Some(quiet))
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -- From Dynamic/Decoder
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/// https://www.erlang.org/doc/apps/kernel/disk_log.html#t:open_ret/0
fn to_open_return_decoder() {
  decode.one_of(to_open_return_result_decoder(), [
    to_open_return_repaired_decoder(),
  ])
}

fn to_open_return_result_decoder() {
  use key <- decode.field(0, atom.decoder())
  use value <- decode.field(1, decode.dynamic)

  case atom.to_string(key) {
    "ok" -> DiskLog(value) |> OpenReturn |> Ok |> decode.success
    "error" -> Error(value) |> decode.success
    key ->
      DiskLog(dynamic.nil())
      |> OpenReturn()
      |> Ok()
      |> decode.failure("gbr:disk_log decoder open_return unknown " <> key)
  }
}

fn to_open_return_repaired_decoder() {
  use key <- decode.field(0, atom.decoder())
  use log <- decode.field(1, decode.dynamic)
  use recovered <- decode.field(1, decode.int)
  use bad_bytes <- decode.field(1, decode.int)

  case atom.to_string(key) {
    "repaired" ->
      DiskLog(log)
      |> OpenRepaired(recovered:, bad_bytes:)
      |> Ok()
      |> decode.success()
    key ->
      DiskLog(dynamic.nil())
      |> OpenRepaired(recovered: 0, bad_bytes: 0)
      |> Ok()
      |> decode.failure("gbr:disk_log decoder open_return unknown " <> key)
  }
}

fn to_chunk_dynamic_decoder() {
  decode.one_of(to_chunk_eof_decoder(), [to_chunk_dynamic_direct_decoder()])
}

fn to_chunk_eof_decoder() {
  use key <- decode.then(atom.decoder())

  case atom.to_string(key) {
    "eof" -> Eof |> decode.success
    key -> decode.failure(Eof, key)
  }
}

fn to_chunk_dynamic_direct_decoder() {
  use continuation <- decode.field(0, decode.dynamic)
  use data <- decode.field(1, decode.list(decode.dynamic))
  use bad_bytes <- decode.field(2, decode.optional(decode.int))

  Continuation(continuation)
  |> ChunkData(data:, bad_bytes:)
  |> decode.success
}

fn to_chunk_binary_decoder() {
  decode.one_of(to_chunk_eof_decoder(), [to_chunk_binary_direct_decoder()])
}

fn to_chunk_binary_direct_decoder() {
  use continuation <- decode.field(0, decode.dynamic)
  use data <- decode.field(1, decode.list(decode.bit_array))
  use bad_bytes <- decode.field(2, decode.optional(decode.int))

  Continuation(continuation)
  |> ChunkData(data:, bad_bytes:)
  |> decode.success
}

fn to_log_or_undefined_decoder() {
  decode.one_of(to_undefined_decoder(), [to_log_decoder()])
}

fn to_log_decoder() {
  use key <- decode.field(0, atom.decoder())
  use value <- decode.field(1, decode.dynamic)

  case atom.to_string(key) {
    "ok" -> DiskLog(value) |> Some |> decode.success
    key -> decode.failure(None, key)
  }
}

fn to_undefined_decoder() {
  use undefined <- decode.then(atom.decoder())

  case atom.to_string(undefined) {
    "undefined" -> decode.success(None)
    _ -> decode.failure(None, "gbr:ets decoder error not found 'undefined'")
  }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -- To Dynamic/Encoder
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

@internal
pub fn to_dynamic_options(options: Builder) -> List(Dynamic) {
  let Builder(
    name:,
    link_to:,
    file:,
    repair:,
    type_:,
    format:,
    size:,
    notify:,
    mode:,
    quiet:,
    head:,
  ) = options
  // auxiliares
  let to_proplist = fn(o, key) {
    let key = get_atom(key) |> atom.to_dynamic

    option.map(o, fn(o) { [[key, o] |> dynamic.array] })
    |> option.unwrap([])
  }
  let head_map = fn(head: InfoLogHead) {
    case head {
      InfoHead(head) ->
        head
        |> to_proplist("head")
        |> Some
      InfoHeadFun(#(m, f, a)) ->
        [m |> atom.to_dynamic, f |> atom.to_dynamic, dynamic.list(a)]
        |> dynamic.array
        |> Some
        |> to_proplist("head_func")
        |> Some
    }
  }
  // conversores
  let name =
    [get_atom("name") |> atom.to_dynamic, get_atom(name) |> atom.to_dynamic]
    |> dynamic.array
  let link_to =
    option.map(link_to, ffi_pid_to_dynamic)
    |> to_proplist("link_to")
  let file =
    option.map(file, ffi_charlist_to_dynamic)
    |> to_proplist("file")
  let repair =
    option.map(repair, atom.to_dynamic)
    |> to_proplist("repair")
  let type_ =
    option.map(type_, ffi_log_type_to_dynamic)
    |> to_proplist("type")
  let format =
    option.map(format, ffi_log_format_to_dynamic)
    |> to_proplist("format")
  let size =
    option.map(size, to_dynamic_log_size)
    |> to_proplist("size")
  let notify =
    option.map(notify, dynamic.bool)
    |> to_proplist("notify")
  let mode =
    option.map(mode, ffi_log_mode_to_dynamic)
    |> to_proplist("mode")
  let quiet =
    option.map(quiet, dynamic.bool)
    |> to_proplist("quiet")
  let head =
    option.then(head, head_map)
    |> option.unwrap([])

  // proplist
  list.append([], [name])
  |> list.append(link_to)
  |> list.append(file)
  |> list.append(repair)
  |> list.append(type_)
  |> list.append(format)
  |> list.append(size)
  |> list.append(notify)
  |> list.append(mode)
  |> list.append(quiet)
  |> list.append(head)
}

/// TODO problemão
fn to_dynamic_log_size(v: LogSize) -> Dynamic {
  case v {
    options.Infinity -> get_atom("infinity") |> atom.to_dynamic()
    options.MaxBytes(max) -> dynamic.int(max)
    options.MaxNoBytes(max_bytes:, max_files:) ->
      [dynamic.int(max_bytes), dynamic.int(max_files)] |> dynamic.array
  }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -- FFI
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

@external(erlang, "disk_log", "all")
fn ffi_disk_log_all() -> List(Dynamic)

@external(erlang, "disk_log", "breopen")
fn ffi_disk_log_breopen(log: Dynamic, file: Dynamic, bhead: Dynamic) -> Dynamic

@external(erlang, "disk_log", "btruncate")
fn ffi_disk_log_btruncate(log: Dynamic, bhead: Dynamic) -> Dynamic

@external(erlang, "disk_log", "block")
fn ffi_disk_log_block(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "block")
fn ffi_disk_log_block_queue_log_rec(log: Dynamic, queue: Bool) -> Dynamic

@external(erlang, "disk_log", "bchunk")
fn ffi_disk_log_bchunk(log: Dynamic, continuation: Dynamic) -> Dynamic

@external(erlang, "disk_log", "bchunk")
fn ffi_disk_log_bchunk_length(
  log: Dynamic,
  continuation: Dynamic,
  length: Int,
) -> Dynamic

@external(erlang, "disk_log", "balog_terms")
fn ffi_disk_log_balog_terms(log: Dynamic, bytes_list: List(BitArray)) -> Dynamic

@external(erlang, "disk_log", "blog_terms")
fn ffi_disk_log_blog_terms(log: Dynamic, bytes_list: List(BitArray)) -> Dynamic

@external(erlang, "disk_log", "alog_terms")
fn ffi_disk_log_alog_terms(log: Dynamic, term_list: List(Dynamic)) -> Dynamic

@external(erlang, "disk_log", "change_size")
fn ffi_disk_log_change_size(log: Dynamic, size: Dynamic) -> Dynamic

@external(erlang, "disk_log", "change_notify")
fn ffi_disk_log_change_notify(
  log: Dynamic,
  owner: process.Pid,
  notify: Bool,
) -> Dynamic

@external(erlang, "disk_log", "change_header")
fn ffi_disk_log_change_header(log: Dynamic, header: Dynamic) -> Dynamic

@external(erlang, "disk_log", "open")
fn ffi_disk_log_open(options: List(Dynamic)) -> Dynamic

@external(erlang, "disk_log", "close")
fn ffi_disk_log_close(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "info")
fn ffi_disk_log_info(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "log")
fn ffi_disk_log_write(log: Dynamic, data: Dynamic) -> Dynamic

@external(erlang, "disk_log", "blog")
fn ffi_disk_log_write_binary(log: Dynamic, data: BitArray) -> Dynamic

@external(erlang, "disk_log", "alog")
fn ffi_disk_log_write_async(log: Dynamic, data: Dynamic) -> Dynamic

@external(erlang, "disk_log", "log_terms")
fn ffi_disk_log_log_terms(log: Dynamic, term_list: List(Dynamic)) -> Dynamic

@external(erlang, "disk_log", "balog")
fn ffi_disk_log_balog(log: Dynamic, data: BitArray) -> Dynamic

@external(erlang, "disk_log", "sync")
fn ffi_disk_log_sync(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "chunk")
fn ffi_disk_log_chunk(log: Dynamic, cont: Dynamic) -> Dynamic

@external(erlang, "disk_log", "chunk")
fn ffi_disk_log_chunk_length(
  log: Dynamic,
  cont: Dynamic,
  length: Int,
) -> Dynamic

@external(erlang, "disk_log", "unblock")
fn ffi_disk_log_unblock(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "next_file")
fn ffi_disk_log_next_file(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "reopen")
fn ffi_disk_log_reopen(log: Dynamic, file: charlist.Charlist) -> Dynamic

@external(erlang, "disk_log", "reopen")
fn ffi_disk_log_reopen_head(
  log: Dynamic,
  file: charlist.Charlist,
  head: Dynamic,
) -> Dynamic

@external(erlang, "disk_log", "pid2name")
fn ffi_disk_log_pid2name(pid: process.Pid) -> Dynamic

@external(erlang, "disk_log", "chunk_step")
fn ffi_disk_log_chunk_step(
  log: Dynamic,
  continuation: Dynamic,
  step: Int,
) -> Result(Dynamic, Dynamic)

@external(erlang, "disk_log", "chunk_info")
fn ffi_disk_log_chunk_info(continuation: Dynamic) -> Dynamic

@external(erlang, "disk_log", "truncate")
fn ffi_disk_log_truncate(log: Dynamic) -> Dynamic

@external(erlang, "disk_log", "truncate")
fn ffi_disk_log_truncate_head(log: Dynamic, head: Dynamic) -> Dynamic

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -- Interno
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

@external(erlang, "disk_log", "format_error")
fn ffi_disk_log_format_error(e: Dynamic) -> charlist.Charlist

const const_erl_true = "true"

const const_erl_false = "false"

const const_erl_truncate = "truncate"

fn get_atom_truncate() {
  get_atom(const_erl_truncate)
}

fn get_atom_true() {
  get_atom(const_erl_true)
}

fn get_atom_false() {
  get_atom(const_erl_false)
}

/// Retorna ou cria um novo atom erlang.
fn get_atom(get: String) {
  atom.get(get)
  |> result.unwrap(atom.create(get))
}

@external(erlang, "gbr_disk_log_ffi", "result_normalize")
fn result_normalize(result: Dynamic) -> Result(a, b)

@external(erlang, "gleam_stdlib", "identity")
fn ffi_pid_to_dynamic(v: process.Pid) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn ffi_charlist_to_dynamic(v: charlist.Charlist) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn ffi_log_type_to_dynamic(v: LogType) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn ffi_log_format_to_dynamic(v: LogFormat) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn ffi_log_mode_to_dynamic(v: LogMode) -> Dynamic
