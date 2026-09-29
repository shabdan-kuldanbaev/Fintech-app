import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Куда уходит перехваченная ошибка.
///
/// Отдельная точка нужна по двум причинам: тест может убедиться, что ошибка
/// действительно доехала, а не растворилась; и когда понадобится журнал или
/// внешний сборщик отчётов, подключать его придётся здесь одному, а не в
/// каждом месте установки.
typedef ErrorReporter = void Function(FlutterErrorDetails details);

/// Единственное место, где приложение узнаёт о своих ошибках
/// (ревью 2026-09-11, находка 4).
///
/// До этого не стоял ни один обработчик: всё, что падало асинхронно,
/// исчезало бесследно — и именно поэтому остальные тихие отказы были не
/// видны. Вызывается один раз из `main()` **до** `runApp`, чтобы поймать и
/// то, что упадёт во время запуска.
///
/// [reporter] по умолчанию — [FlutterError.presentError]: в отладке он
/// печатает ошибку со стеком в консоль, в релизе стоит дёшево. Он же —
/// поведение Flutter по умолчанию для синхронных ошибок; ценность установки
/// в том, что к тому же приёмнику подключаются и асинхронные.
///
/// Намеренно без `runZonedGuarded`: [PlatformDispatcher.onError] ловит то же
/// самое, но не уводит приложение в отдельную зону — иначе ошибки, брошенные
/// из зоны биндинга, до обработчика не доходят.
///
/// Чужой приёмник [FlutterError.onError] не затирается, а вызывается следом
/// за [reporter] — см. `_previousHandler` (аудит 2026-09-12).
void installErrorHandlers({ErrorReporter? reporter}) {
  final report = reporter ?? FlutterError.presentError;

  final previous = _previousHandler();

  // Синхронные ошибки Flutter: build, layout, paint и всё, что framework
  // сообщает через FlutterError.reportError.
  void handleFlutterError(FlutterErrorDetails details) {
    report(details);
    // Владелец прежнего приёмника узнаёт об ошибке так же, как узнал бы без
    // нас: приложение подключается к цепочке, а не заменяет её собой.
    previous?.call(details);
  }

  _installed = handleFlutterError;
  _chainedTo = previous;
  FlutterError.onError = handleFlutterError;

  // Ошибки вне дерева виджетов: необработанные Future, ошибки в колбэках
  // платформы. `true` означает «ошибка обработана» — без него движок считает
  // её фатальной.
  PlatformDispatcher.instance.onError = (error, stack) {
    report(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'fintech',
      ),
    );
    return true;
  };

  // Красный экран в отладке оставляем: там ошибка и должна быть заметна.
  // В релизе он занимает место всего экрана и делает приложение непригодным,
  // поэтому сломанное поддерево заменяется пустым местом — отказывает только
  // оно, остальной экран продолжает работать.
  if (!kDebugMode) {
    ErrorWidget.builder = buildBrokenSubtreePlaceholder;
  }
}

/// Приёмник, поставленный нами, и тот, что стоял до него.
///
/// Нужны, чтобы повторный вызов [installErrorHandlers] цеплялся не к самому
/// себе: `app.main()` в сценариях `integration_test` вызывается в каждом
/// тесте, и без этого одна ошибка уезжала бы в отчёт по разу на каждый вызов.
FlutterExceptionHandler? _installed;
FlutterExceptionHandler? _chainedTo;

/// Приёмник, которому надо передавать ошибку следом за своим — или `null`,
/// если передавать некому.
///
/// Зачем вообще передавать. `FlutterError.onError` — одна глобальная ячейка,
/// и в тестах её занимает `flutter_test`: биндинг ставит туда сборщик, по
/// которому тест и краснеет (`prepareTest`), а возвращает прежний только в
/// `postTest`. Сценарии `integration_test` зовут `app.main()` уже внутри тела
/// теста, так что безусловная запись выбрасывала сборщик биндинга — и
/// переполнения раскладки, ошибки build и paint переставали валить прогон:
/// стенд оставался зелёным на сломанном экране (аудит 2026-09-12).
///
/// [FlutterError.presentError] исключение: это значение по умолчанию, оно
/// никому не принадлежит и умеет только печатать — его место занимает
/// `reporter`, иначе ошибка печаталась бы дважды.
FlutterExceptionHandler? _previousHandler() {
  final current = FlutterError.onError;
  if (identical(current, _installed)) return _chainedTo;
  if (current == FlutterError.presentError) return null;
  return current;
}

/// Замена поддерева, которое не смогло построиться (релизная сборка).
///
/// Пустое место, а не текст извинения: виджет подставляется на место
/// сломанного узла, и его размер заранее неизвестен — любой видимый контент
/// сломал бы вёрстку вокруг сильнее, чем сама ошибка.
Widget buildBrokenSubtreePlaceholder(FlutterErrorDetails details) =>
    const SizedBox.shrink();
