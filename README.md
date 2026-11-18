# GameKill v3

## Camadas de proteção (da mais branda à mais forte)
1. **memory.low 1G no KDE** (session.slice): KWin/Plasma/áudio não vão para o swap quando o jogo esgota a RAM.
2. **Recuperação** (`pre-recovery`): avisa e libera cache/memória ociosa de apps que não são jogos. Não encerra nada.
3. **Watchdog** (`gamekill-watchdog --auto`): encerra só o jogo Steam após 30 s de pressão crítica + recuperação + 10 s de confirmação.
4. **systemd-oomd** (backstop, 80% de pressão por 30 s): KDE marcado `ManagedOOMPreference=omit` (requer `system/install-system.sh`).
5. **OOM do kernel**: jogos recebem `oom_score_adj=700`, e o KWin/Plasma fica em 200, então o kernel escolhe o jogo.

## Failsafes da interface
- plasmashell caiu e o systemd desistiu → o watchdog reinicia (máx. 5×/hora).
- KWin sem responder por ~1 min com jogo aberto → o jogo é encerrado.
- Tela congelada: **Alt+PrtSc+F** (SysRq, requer install-system.sh) → o kernel mata o jogo.
- TTY: Ctrl+Alt+F3, faça login e rode `gamekill-watchdog --kill-now` (ou `gamekill`, interativo). Volte com Ctrl+Alt+F1/F2.
- Atalho: Configurações do Sistema → Atalhos → Adicionar aplicativo → "GameKill: encerrar jogo agora".

## Comandos
`gamekill-watchdog --status | --test | --dry-run | --kill-now`
Logs: `journalctl --user -t gamekill-watchdog -t gamekill-recovery`
AppIDs que nunca devem ser encerrados automaticamente: `protected-appids`.
Desfazer a parte de sistema: `sudo ~/.config/gamekill/system/install-system.sh --uninstall`

## Instalação
```bash
git clone https://github.com/LucasRamos13/gamekill.git
cd gamekill && ./install.sh
sudo ~/.config/gamekill/system/install-system.sh   # opcional, recomendado
```

## Estrutura do repositório
| Caminho | Destino |
|---|---|
| `bin/gamekill` | `~/.local/bin/` — seletor interativo (SIGTERM → SIGKILL) |
| `bin/gamekill-watchdog` | `~/.local/bin/` — watchdog de memória / failsafes do KDE |
| `config/pre-recovery`, `config/protected-appids` | `~/.config/gamekill/` |
| `system/install-system.sh` | `~/.config/gamekill/system/` — parte root (oomd, sysrq, MGLRU) |
| `systemd/` | `~/.config/systemd/user/` — serviço e drop-ins de proteção |
| `applications/gamekill-now.desktop` | `~/.local/share/applications/` |
