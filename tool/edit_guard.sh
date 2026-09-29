#!/bin/zsh
# Хук Claude Code (PreToolUse и PostToolUse, Write|Edit): правила про файлы,
# которые раньше держались на памяти.
#
#   PreToolUse   *.g.dart — правка отменяется (код 2): файл порождён codegen и
#                будет затёрт следующим build_runner.
#   PostToolUse  lib/**.dart — прогоняются стражи
#                test/architecture/invariants_test.dart (замер 2026-09-18:
#                2,4 с). Нарушение инварианта модель видит сразу после правки,
#                когда исправить его дешевле всего, а не перед коммитом.
#   PostToolUse  lib/data/db/tables.dart — модели напоминается правило
#                «до релиза» из CLAUDE.md: onCreate, schemaVersion, codegen.
#
# EDIT_GUARD_INVARIANTS подменяет команду стражей — только для теста.
#
# Проверка — test/tool/commit_gate_test.dart (перенос из Flashcards — этап 5).
set -u
INPUT=$(cat)
EVENT=$(print -r -- "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
FILE=$(print -r -- "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ $EVENT == PreToolUse && $FILE == *.g.dart ]]; then
  print -u2 "edit_guard: $FILE порождён codegen — руками не правится."
  print -u2 "Правьте исходник и запустите:"
  print -u2 "  dart run build_runner build --delete-conflicting-outputs"
  exit 2
fi

[[ $EVENT == PostToolUse && $FILE == */lib/*.dart ]] || exit 0

cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
INVARIANTS=${EDIT_GUARD_INVARIANTS:-}
if [[ -z $INVARIANTS && -f test/architecture/invariants_test.dart ]]; then
  INVARIANTS='flutter test test/architecture/invariants_test.dart'
fi
# ЗАМОК. В волне агенты правят разом, и параллельные `flutter test` бьют друг
# другу build/native_assets: замер 2026-09-19 — 3 стража из 4 краснели ложно
# («Failed to code sign binary»). Стражи идут по очереди; тот же замок берёт
# `tool/verify.sh` на время тестов. Замок снимается с выходом скрипта. Не
# дождались за 100 с (хуку дано 120) — молчим: ложное «красно» хуже пропуска,
# а полный прогон перед коммитом всё равно будет.
if [[ -n $INVARIANTS ]]; then
  zmodload zsh/system
  mkdir -p build && : >> build/flutter-test.lock
  if ! zsystem flock -t 100 build/flutter-test.lock 2>/dev/null; then
    print -u2 "edit_guard: очередь к стражам дольше 100 с — пропускаю, их прогонит tool/verify.sh."
    exit 0
  fi
fi
if [[ -n $INVARIANTS ]] && ! OUT=$(${=INVARIANTS} 2>&1); then
  print -u2 "edit_guard: после правки $FILE стражи красные ($INVARIANTS):"
  print -u2 -r -- "$OUT" | tail -25
  print -u2 "Страж не ослабляется: правится код. Исключение — только явное и с причиной."
  exit 2
fi

if [[ $FILE == */lib/data/db/tables.dart ]]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext:
    "tables.dart изменён. До релиза (CLAUDE.md): то же изменение дописывается в onCreate в lib/data/db/database.dart (spec.md §3.2), schemaVersion остаётся 1, затем dart run build_runner build --delete-conflicting-outputs; приложение на устройстве переустанавливается. spec.md §3.1 обновляется той же правкой."}}'
fi
exit 0
