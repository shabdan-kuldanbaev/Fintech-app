#!/bin/zsh
# Отпечаток непроверенного кода: tool/tree_hash.sh
#
# Печатает `clean`, если проверяемые пути совпадают с HEAD, иначе — хеш
# содержимого всех изменённых, удалённых и новых файлов в этих путях.
#
# ЗАЧЕМ. `tool/verify.sh` после зелёного прогона записывает этот отпечаток в
# штамп, `tool/commit_gate.sh` перед коммитом сверяет его с текущим. Совпало —
# коммитится ровно то, что проверено.
#
# ПОЧЕМУ НЕ `git diff | shasum`. Отпечаток не должен зависеть от индекса:
# между прогоном и коммитом стоит `git add`, и новый файл переезжает из
# «неотслеживаемых» в «изменённые». Поэтому хешируются имена и содержимое
# файлов в рабочем каталоге, а не вывод diff.
#
# Проверка — test/tool/commit_gate_test.dart (перенос из Flashcards — этап 5).
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

# Только то, что видят `dart analyze` и `flutter test`. Документация и ios/
# прогоном не проверяются, и требовать прогон ради них — приучать его обходить.
PATHS=()
for p in lib test integration_test packages tool pubspec.yaml pubspec.lock \
         analysis_options.yaml; do
  [[ -e $p ]] && PATHS+=($p)
done
(( ${#PATHS} == 0 )) && { print clean; exit 0; }

FILES=$(
  {
    git diff HEAD --name-only -z -- $PATHS
    git ls-files --others --exclude-standard -z -- $PATHS
  } | tr '\0' '\n' | sort -u
)
[[ -z "$FILES" ]] && { print clean; exit 0; }

print -r -- "$FILES" | while IFS= read -r f; do
  if [[ -f $f ]]; then
    print -r -- "$f $(shasum < $f)"
  else
    print -r -- "$f deleted"
  fi
done | shasum | cut -d' ' -f1
