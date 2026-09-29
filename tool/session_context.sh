#!/bin/zsh
# Хук Claude Code (SessionStart): кладёт в контекст новой сессии раздел «Сейчас»
# из docs/PROGRESS.md и состояние дерева.
#
# ЗАЧЕМ. После `/clear` и после сжатия контекста модель не помнит, на чём
# остановилась работа. Обычный текст из stdout хука SessionStart среда добавляет
# в контекст — сессия начинается с места, а не с нуля. Журнал ниже раздела
# «Сейчас» сюда не попадает: он читается по месту.
#
# Хук ничего не блокирует и при любой ошибке молча выходит с 0.
set -u
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0

print "=== docs/PROGRESS.md — «Сейчас» ==="
awk '/^## Сейчас/ {p=1; print; next} /^## / {p=0} p' docs/PROGRESS.md 2>/dev/null

print "=== git ==="
git log -3 --format='%h %s' 2>/dev/null
CHANGED=$(git status --short 2>/dev/null)
if [[ -n $CHANGED ]]; then
  print "Незакоммиченные правки:"
  print -r -- "$CHANGED" | head -20
else
  print "Дерево чистое."
fi
if [[ -f build/verify-stamp && $(tool/tree_hash.sh 2>/dev/null) == $(cat build/verify-stamp) ]]; then
  print "Штамп tool/verify.sh совпадает с текущим кодом: зелёный прогон над ним был."
fi
exit 0
