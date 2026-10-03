import '../core/localization/app_language.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/record.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/debts/debt_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/transactions/transaction_screen.dart';
import 'providers.dart';

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
          setState(() => error = context.tr('Could not search local data.'));
        }
      } finally {
        if (mounted && version == generation) setState(() => busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: TextField(
      autofocus: true,
      decoration: InputDecoration(
        hintText: context.tr('Search your finances…'),
        prefixIcon: const Icon(Icons.search),
      ),
      onChanged: search,
    ),
    content: SizedBox(
      width: 650,
      height: 450,
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      context.tr(
                        'Search transactions, tags, people and notes.',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final r = results[i],
                          title = r.text('name').isNotEmpty
                              ? r.text('name')
                              : r.text('title').isNotEmpty
                              ? r.text('title')
                              : r.text('description').isNotEmpty
                              ? r.text('description')
                              : context.tr('Debt');
                      return ListTile(
                        title: Text(title),
                        subtitle: Text(context.tr(r.entity.name)),
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
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Close')),
      ),
    ],
  );
}
