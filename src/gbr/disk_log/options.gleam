////
//// GBR: Erlang Disk Log Options Module
////

//
// ----- Tipos de opções
//

/// O formato dos dados no log.
pub type LogFormat {
  /// Internal Erlang term.
  Internal
  /// External binary.
  External
}

/// O modo de acesso para o log.
pub type LogMode {
  /// Abre o log em modo somente-leitura.
  ReadOnly
  /// Abre o log em modo leitura-escrita.
  ReadWrite
}

/// O tamanho máximo do log.
pub type LogSize {
  /// Sem limites.
  Infinity
  /// O máximo de bytes para um arquivo.
  MaxBytes(Int)
  /// O máximo de bytes e o número de arquivos para o wrap log.
  MaxNoBytes(max_bytes: Int, max_files: Int)
}

/// O tipo de log.
pub type LogType {
  /// Um simples arquivo de log.
  Halt
  /// Uma sequência de arquivos `wrap`.
  Wrap
  /// Uma sequência de arquivos `rotate` (somente `DiskLogFormat.External`).
  Rotate
}
