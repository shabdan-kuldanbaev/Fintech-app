import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/format.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/header.dart';
import '../domain/category.dart';

/// «Categories» (§8.3): расходы и доходы, порядок перетаскиванием,
/// создание и правка.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryKind _kind = CategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(categoriesProvider).value;
    return GlassScaffold(
      header: ScreenHeader(
        leading: HeaderBack(tooltip: l.back),
        title: l.categoriesTitle,
        trailing: GlassIconButton(
          icon: Icons.add_rounded,
          tooltip: l.categoryNew,
          onPressed: () => unawaited(context.push(Routes.newCategory(_kind))),
        ),
      ),
      body: (context) {
        if (all == null) return const SizedBox.shrink();
        final list = all.where((c) => c.kind == _kind && !c.isSystem).toList();
        final top = MediaQuery.paddingOf(context).top + AppSizes.header;
        return Column(
          children: [
            SizedBox(height: top + AppSpacing.s8),
            AppSegmented<CategoryKind>(
              values: CategoryKind.values,
              labels: [l.kindExpense, l.kindIncome],
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: AppSpacing.s12),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.scrollBottom(context)),
                itemCount: list.length,
                onReorderItem: (from, to) {
                  final ids = list.map((c) => c.id).toList();
                  final moved = ids.removeAt(from);
                  ids.insert(to, moved);
                  unawaited(ref.read(categoryRepositoryProvider).reorder(ids));
                },
                itemBuilder: (context, i) {
                  final c = list[i];
                  return Padding(
                    key: ValueKey(c.id),
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: SoftCard(
                      radius: AppRadius.row,
                      padding: EdgeInsets.zero,
                      child: AppRow(
                        leading: IconBubble(iconKey: c.iconKey, colorKey: c.colorKey, size: 40),
                        title: categoryName(l, c),
                        trailing: const Icon(Icons.drag_handle_rounded),
                        onTap: () => unawaited(context.push(Routes.category(c.id))),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
