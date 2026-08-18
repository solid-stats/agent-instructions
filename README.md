# agent-instructions

**Русский** · [English](README.en.md)

Единый источник общих для всех AI-агентов правил платформы **Solid Stats** — статистики игр
сообщества [Solid Games](https://sg.zone) (ArmA 3). Раньше эти правила были задублированы вручную
по `AGENTS.md` каждого репозитория (например, абзац «Skills First» — дословно одинаковый в
`web`, `server-2`, `replays-fetcher`, `replay-parser-2`) или жили не на своём месте (внутри
триггерящегося skill'а `solidstats-shared-project-standards`, который для этого не предназначен).

Это вспомогательный (supporting) репозиторий: рантайм-границ не несёт — задаёт общий контент,
который импортируют остальные репозитории.

## Что здесь лежит

- [`shared/AGENTS.md`](shared/AGENTS.md) — фрагмент, который каждый репо-потребитель
  подключает через `@.agent-instructions/AGENTS.md` в своём корневом `AGENTS.md`: session
  hygiene, git-конвенции (включая политику auto commit + push), security minimums, risk
  management, documentation language, MCP/doc-lookup правила.
- [`gsd/common-config.json`](gsd/common-config.json) — общее подмножество ключей
  `.planning/config.json` (GSD), синхронизируемое отдельным скриптом, без затрагивания
  repo-специфичных ключей (`project_code`, `agent_skills`, `test_command`, …).
- [`config/repositories.tsv`](config/repositories.tsv) — манифест репозиториев-потребителей и
  их тира.
- [`scripts/install-bridge.sh`](scripts/install-bridge.sh) — разовая установка бриджа в новый
  репозиторий.
- [`scripts/sync-gsd-config.mjs`](scripts/sync-gsd-config.mjs) — точечный merge общих ключей
  GSD-конфига по dotted-path, без затрагивания остального файла.
- [`.github/workflows/sync-on-release.yml`](.github/workflows/sync-on-release.yml) — при
  публикации релиза (бамп `CONTRACT_VERSION`) открывает PR с обновлением в каждый репозиторий
  из манифеста. Мерж — вручную, авто-мерджа нет.

## Как обновляется контент в репо-потребителях

Свежесть — через **auto-PR, а не через ручной клон**: контент вендорится (закоммичен в
репо-потребителе, не в `.gitignore`), диффы видны прямо в PR. Ручной клон-паттерн (как в
VocalClub `agent-instructions`) здесь осознанно не используется — см. `.planning/` этого
репозитория для истории решения.

## Первичная установка нового репо-потребителя

```bash
git clone https://github.com/solid-stats/agent-instructions.git /tmp/agent-instructions
sh /tmp/agent-instructions/scripts/install-bridge.sh --root .
```

## Разработка

```sh
sh -n scripts/install-bridge.sh
sh tests/test-install-bridge.sh
node scripts/sync-gsd-config.mjs <path-to-repo> --dry-run
```

## Лицензия

MIT — см. [LICENSE](LICENSE).
