/// Очередь тапов по уведомлениям (перенос из Jattap): тап, пришедший до
/// того, как роутер в дереве, ждёт, а не теряется.
class NotificationTaps {
  void Function(String payload)? _handler;
  final List<String> _pending = [];

  void report(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final handler = _handler;
    if (handler == null) {
      _pending.add(payload);
      return;
    }
    handler(payload);
  }

  void attach(void Function(String payload) handler) {
    _handler = handler;
    final queued = List<String>.of(_pending);
    _pending.clear();
    queued.forEach(handler);
  }
}
