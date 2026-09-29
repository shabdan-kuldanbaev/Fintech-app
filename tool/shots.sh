#!/bin/zsh
# Кадры экранов: tool/shots.sh [фильтр]
# Рендерит экраны в build/shots/*.png (обе темы, обе локали, 393 и 320 pt)
# на демо-данных с настоящими шрифтами. Смотреть глазами — скилл /shots.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
mkdir -p build/shots
FILTER=${1:-}
flutter test test_shots/shots_test.dart --update-goldens --dart-define=SHOTS=$FILTER "${@:2}" 2>&1 | tail -3
print "shots: $(ls build/shots/*.png 2>/dev/null | wc -l | tr -d ' ') кадров в build/shots/"
