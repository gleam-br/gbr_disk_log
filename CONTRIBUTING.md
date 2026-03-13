# Contribuindo para o GBR Disk Log 🚀

Primeiramente, obrigado por considerar contribuir para o `gbr_disk_log`! Este projeto faz parte do ecossistema [Gleam-BR](https://gleam.dev.br) mantido pela Freunde Von Ideen (FVideen).

Nossa missão é construir fundações inquebráveis para a Erlang VM (BEAM) usando a segurança de tipos da linguagem Gleam. Se você gosta de sistemas distribuídos, tolerância a falhas e TDD, você está no lugar certo!

## 🛠️ Configuração do Ambiente

Para desenvolver neste projeto, você precisará de:
* [Gleam](https://gleam.run/getting-started/) (v1.0.0 ou superior)
* [Erlang/OTP](https://www.erlang.org/downloads) (v26 ou superior)

Clone o repositório e baixe as dependências:
```bash
git clone [https://github.com/gleam-br/gbr_disk_log.git](https://github.com/gleam-br/gbr_disk_log.git)
cd gbr_disk_log
gleam deps download
gleam test

```

## 🏗️ Arquitetura do Projeto (O Padrão Fachada)

Nós utilizamos o **Facade Pattern** rigorosamente para manter a API pública limpa e esconder a complexidade do FFI (Foreign Function Interface) com o Erlang.

* **`src/gbr/disk_log.gleam`:** A Fachada. É o único arquivo que os usuários da biblioteca devem importar. Ele apenas re-exporta tipos e funções seguras.
* **`src/gbr/disk_log/core.gleam`:** O motor interno. Onde os tipos opacos e as assinaturas `@external` do Erlang vivem.
* **`src/gbr/disk_log/core_ffi.erl`:** O código nativo Erlang que conversa diretamente com o módulo `disk_log` do OTP.

## 📜 As 4 Leis de Ouro da Engenharia (Gleam-BR)

Para que seu Pull Request (PR) seja aprovado rapidamente, ele DEVE seguir as nossas diretrizes arquiteturais:

### 1. Test-Driven Development (TDD) Estrito

Toda nova funcionalidade ou correção de bug deve vir acompanhada de um teste no `gleeunit`.

### 2. Tratamento Seguro de FFI (Erlang <-> Gleam)

O código Erlang nunca deve derrubar a BEAM silenciosamente.

* Todas as chamadas I/O no `core_ffi.erl` devem retornar um `Result` seguro para o Gleam (ex: `{ok, Value}` ou `{error, Reason}`).
* Desempacote os *Custom Types* do Gleam no Erlang utilizando **Pattern Matching** diretamente no cabeçalho da função. É proibido o uso da função `element/X`.

### 3. Tipagem e Construtores

No ecossistema `gleam-br`, nós levamos o *Pattern Matching* a sério.

* Ao exportar *Custom Types* na Fachada, utilize o aliasing: `pub type MyType = core.MyType`.
* **NUNCA** re-exporte construtores de tipo mascarando-os como constantes minúsculas (ex: `pub const halt = core.Halt` é estritamente proibido). Os desenvolvedores devem ser capazes de usar construtores em `PascalCase` em seus blocos `case`.

### 4. Zero `echo`

Código de produção não deve poluir a saída padrão.

* É proibido o uso de `echo`.
* Se precisar debugar algo localmente, remova antes de fazer o commit. Para ferramentas de linha de comando ou testes, prefira usar `gleam/io.println(string.inspect(variavel))`.

## 🔄 Fluxo de Pull Request

1. Faça um **Fork** do repositório e crie uma branch para a sua feature (`git checkout -b feature/minha-feature-incrivel`).
2. Escreva seus testes (TDD).
3. Implemente o código até o `gleam test` passar limpo.
4. Formate o seu código rodando `gleam format`.
5. Faça o commit detalhando o *porquê* da mudança.
6. Abra o Pull Request explicando a sua motivação e confirmando que todos os testes passaram.

Seja bem-vindo à fronteira do ecossistema Gleam/BEAM!
