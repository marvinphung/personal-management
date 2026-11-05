import '../core/localization/app_language.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/record.dart';
import '../core/utils/tag_display.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/debts/debt_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/transactions/transaction_screen.dart';
import 'providers.dart';
import 'theme.dart';

Future<void> showGlobalSearch(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const GlobalSearch());

class GlobalSearch extends ConsumerStatefulWidget {
  const GlobalSearch({super.key});
  @override
  ConsumerState<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends ConsumerState<GlobalSearch> {
  List<Record> results = [];
  Timer? debounce;
  int generation = 0;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void search(String query) {
    debounce?.cancel();
    final version = ++generation;
    if (query.trim().isEmpty) {
      setState(() {
        results = [];
        busy = false;
        error = null;
      });
      return;
    }
    debounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      setState(() => busy = true);
      try {
        final records = await ref
            .read(searchRepositoryProvider.future)
            .then((r) => r?.search(query) ?? Future.value(<Record>[]));
        if (mounted && version == generation) {
          setState(() {
            results = records;
            error = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => error = context.tr('Không thể tìm kiếm dữ liệu.'));
        }
      } finally {
        if (mounted && version == generation) setState(() => busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final content = Column(
      children: [
        if (busy)
          LinearProgressIndicator(minHeight: 2, color: colors.primaryAccent),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(error!, style: TextStyle(color: colors.expense)),
          ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 48,
                        color: colors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tìm kiếm giao dịch, thẻ, người và ghi chú…',
                        style: TextStyle(color: colors.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final r = results[i];
                    final title = r.entity == Entity.tags
                        ? TagDisplay.forRecord(r)
                        : r.text('name').isNotEmpty
                        ? r.text('name')
                        : r.text('title').isNotEmpty
                        ? r.text('title')
                        : r.text('description').isNotEmpty
                        ? r.text('description')
                        : 'Công nợ';

                    final (icon, entityName) = switch (r.entity) {
                      Entity.transactions => (
                        Icons.receipt_long_rounded,
                        'Giao dịch',
                      ),
                      Entity.notes => (Icons.notes_rounded, 'Ghi chú'),
                      Entity.debts => (Icons.handshake_outlined, 'Công nợ'),
                      Entity.people => (
                        Icons.person_outline_rounded,
                        'Người liên quan',
                      ),
                      Entity.categories => (
                        Icons.category_outlined,
                        'Danh mục',
                      ),
                      Entity.tags => (Icons.tag_rounded, 'Thẻ'),
                      Entity.accounts => (
                        Icons.account_balance_wallet_outlined,
                        'Tài khoản',
                      ),
                      _ => (Icons.circle_outlined, r.entity.name),
                    };

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: colors.primaryAccent,
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        entityName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        switch (r.entity) {
                          case Entity.transactions:
                            showTransactionDetail(context, r);
                          case Entity.notes:
                            showNoteForm(context, record: r);
                          case Entity.debts:
                            showDebtDetail(context, r);
                          case Entity.people:
                            showPersonDetail(context, r);
                          default:
                            showCatalogForm(context, r.entity, record: r);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm dữ liệu…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: search,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: content,
        ),
      );
    }

    return AlertDialog(
      title: TextField(
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm dữ liệu tài chính…',
          prefixIcon: Icon(Icons.search, color: colors.textMuted),
        ),
        onChanged: search,
      ),
      content: SizedBox(width: 600, height: 400, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
