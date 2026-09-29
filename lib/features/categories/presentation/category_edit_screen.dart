import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../../../core/icons.dart';
import '../../accounts/presentation/style_pickers.dart';
import '../../transactions/presentation/pickers.dart';
import '../domain/category.dart';

/// Создание и правка категории: имя, иконка, цвет; удаление — с переносом
/// операций в другую категорию (§8.3).
class CategoryEditScreen extends ConsumerStatefulWidget {
  const CategoryEditScreen({super.key, this.id, this.kind = CategoryKind.expense});

  final String? id;
  final CategoryKind kind;

  @override
  ConsumerState<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends ConsumerState<CategoryEditScreen> {
  final _name = TextEditingController();
  String _iconKey = 'other';
  String _colorKey = 'lavender';
  Category? _loaded;
  bool _nameError = false;

  bool get _isNew => widget.id == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _load(Category c) {
    if (_loaded != null) return;
    _loaded = c;
    _name.text = c.name ?? categoryName(context.l10n, c);
    _iconKey = c.iconKey;
    _colorKey = c.colorKey;
  }

  Future<void> _save() async {
    final repo = ref.read(categoryRepositoryProvider);
    final name = _name.text.trim();
    final old = _loaded;
    if (_isNew) {
      if (name.isEmpty) {
        setState(() => _nameError = true);
        return;
      }
      await repo.create(name: name, kind: widget.kind, iconKey: _iconKey, colorKey: _colorKey);
    } else if (old != null) {
      // Имя предустановленной не трогаем, пока его не поменяли.
      final original = old.key == null ? null : categoryName(context.l10n, Category(id: '', key: old.key, kind: old.kind, iconKey: '', colorKey: ''));
      await repo.update(
        old.id,
        name: old.key != null && name == original ? null : name,
        iconKey: _iconKey,
        colorKey: _colorKey,
      );
    }
    if (mounted) context.closeScreen();
  }

  Future<void> _delete(Category c) async {
    final l = context.l10n;
    final repo = ref.read(categoryRepositoryProvider);
    final count = await repo.transactionCount(c.id);
    if (!mounted) return;
    String? moveTo;
    if (count > 0) {
      final all = ref.read(categoriesProvider).value;
      if (all == null) return;
      final target = await pickCategory(
        context,
        all.where((x) => x.kind == c.kind && !x.isSystem && x.id != c.id).toList(),
        title: l.pickCategory,
      );
      if (target == null || !mounted) return;
      moveTo = target.id;
      final ok = await showConfirm(
        context,
        title: l.categoryDeleteTitle,
        body: l.categoryMoveTo(categoryName(l, target)),
        cancel: l.cancel,
        confirm: l.delete,
        destructive: true,
      );
      if (!ok) return;
    } else {
      final ok = await showConfirm(
        context,
        title: l.categoryDeleteTitle,
        body: l.categoryDeleteEmpty,
        cancel: l.cancel,
        confirm: l.delete,
        destructive: true,
      );
      if (!ok) return;
    }
    await repo.delete(c.id, moveTo: moveTo);
    if (mounted) context.closeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(categoriesProvider).value;
    final c = _isNew ? null : all?.where((x) => x.id == widget.id).firstOrNull;
    if (c != null) _load(c);
    final ready = _isNew || c != null;
    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: _isNew ? l.categoryNew : l.categoryEdit,
        trailing: c == null
            ? null
            : GlassIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: l.delete,
                onPressed: () => unawaited(_delete(c)),
              ),
      ),
      bar: ready ? FilledButton(onPressed: () => unawaited(_save()), child: Text(_isNew ? l.create : l.save)) : null,
      body: (context) {
        if (!ready) return const SizedBox.shrink();
        return ListView(
          padding: AppSpacing.scroll(context, top: AppSpacing.s16).copyWith(left: AppSpacing.s16, right: AppSpacing.s16),
          children: [
            Center(child: IconBubble(iconKey: _iconKey, colorKey: _colorKey, size: 64)),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.fieldName, errorText: _nameError ? l.nameRequired : null),
            ),
            const SizedBox(height: AppSpacing.s12),
            RowsCard(
              children: [
                ValueRow(
                  label: l.fieldIcon,
                  value: '',
                  trailing: Icon(iconFor(_iconKey)),
                  onTap: () async {
                    final k = await pickIcon(context, title: l.fieldIcon, colorKey: _colorKey, selected: _iconKey);
                    if (k != null) setState(() => _iconKey = k);
                  },
                ),
                const RowDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s18, AppSpacing.s12, AppSpacing.s18, AppSpacing.s14),
                  child: ColorRow(selected: _colorKey, onChanged: (k) => setState(() => _colorKey = k)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
