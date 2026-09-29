#!/bin/zsh
# Полная проверка одной командой: tool/verify.sh
#
# `dart analyze` + `flutter test` целиком, короткий вердикт последней строкой.
# Это и есть прогон оркестратора из docs/rules/10-agent-workflow.md: его вывод
# прикладывается к словам «готово» и «проверено».
#
# ШТАМП. После зелёного прогона отпечаток кода (`tool/tree_hash.sh`) пишется в
# build/verify-stamp. `tool/commit_gate.sh` не даёт Claude Code закоммитить код
# с другим отпечатком. Штамп стирается в начале прогона: красный или
# прерванный прогон не оставляет после себя зелёного штампа.
#
# Полный вывод — build/verify.log; на экран идёт только хвост упавшего шага.
# VERIFY_ANALYZE / VERIFY_TEST подменяют команды — только для
# test/tool/commit_gate_test.dart (перенос из Flashcards — этап 5).
set -u
HERE=${0:A:h}
cd "$(git rev-parse --show-toplevel)" || exit 1
ANALYZE=${VERIFY_ANALYZE:-dart analyze lib test test_shots}
TEST=${VERIFY_TEST:-flutter test}
STAMP=build/verify-stamp
LOG=build/verify.log

mkdir -p build
rm -f $STAMP
BEFORE=$($HERE/tree_hash.sh) || exit 1
START=$SECONDS

print "verify: $ANALYZE"
if ! ${=ANALYZE} > $LOG 2>&1; then
  tail -30 $LOG
  print -u2 "verify: КРАСНО — анализатор. Полный вывод: $LOG"
  exit 1
fi

# Тот же замок, что у стражей в tool/edit_guard.sh: параллельные `flutter test`
# бьют друг другу build/native_assets. Снимается с выходом скрипта.
zmodload zsh/system
: >> build/flutter-test.lock
zsystem flock -t 300 build/flutter-test.lock 2>/dev/null \
  || print -u2 "verify: замок build/flutter-test.lock занят дольше 300 с — иду без него."

print "verify: $TEST"
if ! ${=TEST} >> $LOG 2>&1; then
  # Имена упавших тестов flutter печатает в самом конце.
  tail -40 $LOG
  print -u2 "verify: КРАСНО — тесты. Полный вывод: $LOG"
  exit 1
fi

# Правка во время прогона: зелёный результат относится к коду, которого уже нет.
AFTER=$($HERE/tree_hash.sh) || exit 1
if [[ $BEFORE != $AFTER ]]; then
  print -u2 "verify: код менялся во время прогона — штамп не ставлю, повторите."
  exit 1
fi

print -r -- "$AFTER" > $STAMP
print "verify: ЗЕЛЕНО за $(( SECONDS - START )) с — $(tail -1 $LOG | sed 's/^[0-9:]* *//')"
