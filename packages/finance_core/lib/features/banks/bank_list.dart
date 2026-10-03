import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'bank_link_form.dart';
import 'sharing_guide.dart';

final bankSettingsProvider = FutureProvider<List<BankSettingDto>>((ref) async {
  return ref.watch(apiClientProvider).getBanks();
});

final userBindingsProvider = FutureProvider<List<BankBindingDto>>((ref) async {
  return ref.watch(apiClientProvider).getBankBindings();
});

class BankListScreen extends ConsumerWidget {
  const BankListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindingsAsync = ref.watch(userBindingsProvider);
    final settingsAsync = ref.watch(bankSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản ngân hàng liên kết'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userBindingsProvider);
              ref.invalidate(bankSettingsProvider);
            },
          ),
        ],
      ),
      body: bindingsAsync.when(
        data: (bindings) {
          if (bindings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Chưa có ngân hàng nào được liên kết.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm tài khoản ngân hàng'),
                    onPressed: () => _openLinkForm(context, ref),
                  ),
                ],
              ),
            );
          }

          final bankSettings = settingsAsync.value ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bindings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final binding = bindings[index];
              final bankSetting = bankSettings.firstOrNullWhere(
                (s) => s.bankCode == binding.bankCode,
              ) ?? BankSettingDto(
                bankCode: binding.bankCode,
                enabled: true,
                instructions: 'Chưa có hướng dẫn',
                version: 1,
              );

              final isVerified = binding.firstReceivedAt != null;

              return Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            binding.bankCode.toUpperCase(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isVerified ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isVerified ? 'Đã nhận dữ liệu' : 'Đang chờ nhận dữ liệu',
                              style: TextStyle(
                                color: isVerified ? Colors.green.shade800 : Colors.amber.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Số tài khoản: ${binding.accountNumber}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('Hướng dẫn chia sẻ'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SharingGuideScreen(bank: bankSetting),
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          TextButton(
                            child: const Text('Đổi số TK'),
                            onPressed: () => _openLinkForm(context, ref, binding),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi tải danh sách: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(userBindingsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openLinkForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openLinkForm(BuildContext context, WidgetRef ref, [BankBindingDto? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BankLinkForm(
        existingBinding: existing,
        onSaved: () {
          Navigator.pop(context);
          ref.invalidate(userBindingsProvider);
        },
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstOrNullWhere(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
