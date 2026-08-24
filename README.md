# agent-instructions

**Русский** · [English](README.en.md)

Единый источник общих для всех AI-агентов правил платформы **Solid Stats** —
статистики игр сообщества [Solid Games](https://sg.zone) (ArmA 3). Раньше эти
правила были задублированы вручную по `AGENTS.md` каждого репозитория. Например,
абзац «Skills First» был одинаковым в `web`, `server-2`, `replays-fetcher` и
`replay-parser-2`. Часть правил жила в триггерящемся skill
`solidstats-shared-project-standards`, который загружается не всегда.

Это вспомогательный (supporting) репозиторий: рантайм-границ не несёт. Он задаёт
версионированный контракт, который генератор встраивает в корневой `AGENTS.md`
и companion-файлы остальных репозиториев.

## Что здесь лежит

- [`shared/AGENTS.md`](shared/AGENTS.md) — источник блока, который генератор
  помещает в начало корневого `AGENTS.md` каждого репозитория-потребителя.
- [`shared/MEMORY.md`](shared/MEMORY.md) — полный контракт SolidStats MemPalace:
  role-wings, recall, semantic capture, corrections и frozen archives.
- [`shared/GSD.md`](shared/GSD.md) — manual GSD adapter при выключенной native
  MemPalace capability.
- [`gsd/common-config.json`](gsd/common-config.json) — общее подмножество
  ключей `.planning/config.json` (GSD), синхронизируемое без затрагивания
  repo-специфичных ключей (`project_code`, `agent_skills`, `test_command`, …).
- [`config/repositories.tsv`](config/repositories.tsv) — манифест
  репозиториев-потребителей и их тира.
- [`scripts/install-bridge.sh`](scripts/install-bridge.sh) — разовая установка
  бриджа в новый репозиторий.
- [`scripts/sync-gsd-config.mjs`](scripts/sync-gsd-config.mjs) — точечный merge
  общих ключей GSD-конфига по dotted-path, без затрагивания остального файла.
- [`scripts/sync-consumers.sh`](scripts/sync-consumers.sh) — локальный
  fail-closed batch rollout во все consumer-репозитории.
- [`CONTRACT_VERSION`](CONTRACT_VERSION) и [`CHANGELOG.md`](CHANGELOG.md) —
  единая SemVer-версия и impact каждого релиза.

## Как обновляется контент в репо-потребителях

Релиз распространяется локально после acceptance gate. Batch-скрипт сначала
проверяет все восемь checkout: каждый должен существовать, быть чистым и точно
совпадать с upstream. Только после общей preflight-проверки он обновляет root
block, companion-контракт и GSD-конфиг. Коммиты и push остаются отдельным,
проверяемым шагом по Git-политике каждого репозитория.

Сгенерированный контракт закоммичен в consumer-репозитории, поэтому diff виден
до публикации. Локальные инструкции остаются за служебными маркерами.
Установщик не записывает корневой `AGENTS.md`, если тот превышает 32 КиБ.

## Первичная установка нового репо-потребителя

```sh
git clone https://github.com/solid-stats/agent-instructions.git /tmp/agent-instructions
sh /tmp/agent-instructions/scripts/install-bridge.sh --root . --repository solid-stats/<repo>
```

## Разработка

```sh
sh -n scripts/install-bridge.sh
sh -n scripts/sync-consumers.sh
sh tests/test-install-bridge.sh
sh tests/test-sync-gsd-config.sh
sh tests/test-sync-consumers.sh
node tests/test-contract.mjs
sh scripts/sync-consumers.sh --workspace-root .. --check
```

## Лицензия

MIT — см. [LICENSE](LICENSE).
