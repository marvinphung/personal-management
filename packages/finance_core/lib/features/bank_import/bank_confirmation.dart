import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import 'bank_draft.dart';
import '../catalog/category_picker.dart';
import '../catalog/tag_picker.dart';
import '../debts/debt_service.dart';

class BankConfirmation {
  static Future<void> save(
    FinanceRepository repository,
    BankDraft draft,
    Record transaction,
    List<Record> tags, {
    Record? borrower,
  }) async {
    if (repository.userId != draft.owner ||
        transaction.id != draft.transactionId) {
      throw const FormatException('Please sign in again');
    }
    if (borrower != null) {
      await DebtService(repository).saveLendingTransaction(
        transaction,
        borrower,
        tags,
        importKey: 'bank:${draft.fingerprint}',
      );
      return;
    }
    await repository.saveTransaction(
      transaction,
      tags,
      importKey: 'bank:${draft.fingerprint}',
    );
  }
}

class BankEventClassificationSheet extends ConsumerStatefulWidget {
  final Record pendingEvent;
  final List<Record> categories;
  final List<Record> tags;
  final Future<void> Function(String categoryId, List<String> tagIds, String userNote) onAccept;
  final Future<void> Function() onDiscard;

  const BankEventClassificationSheet({
    super.key,
    required this.pendingEvent,
    required this.categories,
    required this.tags,
    required this.onAccept,
    required this.onDiscard,
  });

  @override
  ConsumerState<BankEventClassificationSheet> createState() =>
      _BankEventClassificationSheetState();
}

class _BankEventClassificationSheetState
    extends ConsumerState<BankEventClassificationSheet> {
  String? selectedCategoryId;
  Set<String> selectedTagIds = {};
  final noteController = TextEditingController();
  bool showNoteField = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void _onCategorySelected(Record category) {
    setState(() {
      if (selectedCategoryId != category.id) {
        selectedCategoryId = category.id;
        // Changing category clears selected tags but preserves note!
        selectedTagIds.clear();
      }
    });
  }

  Future<void> _handleAccept() async {
    if (selectedCategoryId == null) {
      setState(() => error = 'Vui lòng chọn danh mục');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await widget.onAccept(
        selectedCategoryId!,
        selectedTagIds.toList(),
        noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _handleDiscard() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      await widget.onDiscard();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.pendingEvent;
    final direction = event.text('direction');
    final amount = event.money('amount_vnd');
    final isIncome = direction == 'income';
    final sign = isIncome ? '+' : '-';
    final color = isIncome ? const Color(0xFF1B873F) : const Color(0xFFD32F2F);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Scaffold(
        appBar: AppBar(
          title: const Text('Phân loại biến động'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : _handleDiscard,
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // 1. Read-only bank summary card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$sign ${Money.format(amount, "VND")}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Chip(
                          label: Text(
                            event.text('bank_code').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TK: ${event.text("owner_account_snapshot")}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    Text(
                      'Thời gian: ${event.text("occurred_at").replaceFirst("T", " ").split(".")[0]}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.text('bank_description'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 20),

            // 2. Category selection: 5+Khác Grid
            Text(
              'Chọn danh mục',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CategoryGridPicker(
              direction: direction,
              categories: widget.categories,
              selectedCategoryId: selectedCategoryId,
              onSelected: _onCategorySelected,
            ),

            // 3. Category-specific tags
            if (selectedCategoryId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Thẻ chi tiết (tùy chọn)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TagChipPicker(
                categoryId: selectedCategoryId!,
                allTags: widget.tags,
                selectedTagIds: selectedTagIds,
                onChanged: (tags) => setState(() => selectedTagIds = tags),
              ),
            ],

            const SizedBox(height: 16),

            // 4. Collapsible Personal Note
            if (!showNoteField)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Thêm ghi chú riêng'),
                  onPressed: () => setState(() => showNoteField = true),
                ),
              )
            else
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú cá nhân',
                  hintText: 'Nhập ghi chú thêm cho giao dịch...',
                ),
                maxLines: 2,
              ),

            const SizedBox(height: 24),

            // 5. Final Accept Action
            FilledButton(
              onPressed: (selectedCategoryId == null || busy) ? null : _handleAccept,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Chấp nhận (Lưu vào sổ)', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
