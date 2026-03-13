# 📔 ROTEIRO: Log de Alta Confiabilidade (gbr_disk_log)

## Visão

Wrapper *com segurança de tipos* do `disk_log` do Erlang/OTP para persistência em Edge e Ring Buffers de classe de telecomunicações. Focado em desempenho extremo, segurança de tipos e resiliência a falhas de energia.

---

## 🚀 Fase 1: Núcleo Síncrono (Concluído ✅)
*Foco: Implementação do banco de dados tipado e operações fundamentais.*

- [x] **Tipagem Forte:** Mapeamento de `LogType`, `LogRepair`, `LogMode` e `LogSize`.

- [x] **Operações Básicas:** `open`, `open_opts`, `close`, `log` (síncrono).

- [x] **Persistência:** `sync` para garantir gravações físicas em disco.

- [x] **Leitura:** `chunk` e `start_continuation` para iteração eficiente sobre os dados.
- [x] **Arquitetura de Face:** API pública limpa em `gbr/disk_log`.

---

## 🛠️ Fase 2: Paridade Total (Em Planejamento)
*Foco: Alcançar paridade com os recursos avançados do módulo nativo do Erlang.*

- [ ] **Modos Assíncronos:** Implementar `alog/2` (assíncrono) e `balog/2` (assíncrono binário) para alta taxa de transferência.

- [ ] **Controle de Concorrência:** Adicionar `block/1` e `unblock/1` para operações de manutenção exclusivas.

- [ ] **Inspeção de Estado:** Implementar `info/1` para expor métricas de log internas (tamanho atual, arquivos, etc.).

- [ ] **Rotação Manual:** Implementar `inc_wrap_file/1` para forçar alterações de arquivo em logs do tipo `wrap`.
- [ ] **Reparo Avançado:** Melhorar o tratamento de retornos `{repaired, ...}` para expor métricas de recuperação.
