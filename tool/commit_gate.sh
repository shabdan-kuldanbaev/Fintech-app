#!/bin/zsh
# Хук Claude Code (PreToolUse, Bash): коммит кода только после зелёного прогона.
#
# На stdin — JSON вызова инструмента. Если команда содержит `git commit`, а
# отпечаток кода (`tool/tree_hash.sh`) не совпадает со штампом последнего
# зелёного `tool/verify.sh`, хук выходит с кодом 2 — Claude Code отменяет
# команду и показывает модели текст из stderr.
#
# ЗАЧЕМ. «Перед каждым коммитом — полный прогон» было договорённостью, которую
# держал только тот, кто о ней помнил. Отчёт «тесты зелёные» — заявление;
# штамп — след настоящего прогона над ровно этим кодом.
#
# Человека хук не касается: коммит из своего терминала идёт мимо него.
# Проверка — test/tool/commit_gate_test.dart (перенос из Flashcards — этап 5).
set -u
CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

# `git commit`, в том числе `git -C dir commit`, в цепочке (`&&`, `;` — и без
# пробела перед оператором) и через табуляцию.
# `git log --grep commit` и `git commit-tree` сюда не попадают.
# Чего ворота НЕ видят: коммит изнутри скрипта (`zsh x.sh`) — хук читает только
# текст команды. Это страховка от забывчивости, а не от обхода.
print -r -- "$CMD" | grep -Eq \
  '(^|[^[:alnum:]_./-])git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([^[:alnum:]_-]|$)' \
  || exit 0

cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
NOW=$(${0:A:h}/tree_hash.sh) || exit 0
[[ $NOW == clean ]] && exit 0

STAMP=$(cat build/verify-stamp 2>/dev/null)
[[ $NOW == $STAMP ]] && exit 0

print -u2 "commit_gate: код изменён, а зелёного прогона над ним нет."
print -u2 "Запустите tool/verify.sh и коммитьте после строки «verify: ЗЕЛЕНО»."
print -u2 "Правка после прогона сбрасывает штамп — так и задумано."
exit 2
