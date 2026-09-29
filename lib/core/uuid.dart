import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Новый первичный ключ: UUID v4 (spec.md I1).
String newId() => _uuid.v4();
