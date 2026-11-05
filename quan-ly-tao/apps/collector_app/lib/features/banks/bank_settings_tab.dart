import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

class BankSettingsTab extends StatefulWidget {
  final ApiClient apiClient;

  const BankSettingsTab({super.key, required this.apiClient});

  @override
  State<BankSettingsTab> createState() => _BankSettingsTabState();
}

class _BankSettingsTabState extends State<BankSettingsTab> {
  List<Map<String, dynamic>> banks = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await widget.apiClient.getAdminBanks();
      setState(() => banks = list);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _editBank(Map<String, dynamic> bank) {
    final code = bank['bank_code'] as String;
    final accountCtrl = TextEditingController(text: bank['receiver_account'] ?? '');
    final nameCtrl = TextEditingController(text: bank['receiver_name'] ?? '');
    final instrCtrl = TextEditingController(text: bank['instructions'] ?? '');
    bool enabled = bank['enabled'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Cấu hình nhận tin: ${code.toUpperCase()}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật nhận thông báo'),
                  value: enabled,
                  onChanged: (val) => setDialogState(() => enabled = val),
                ),
                TextField(
                  controller: accountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số tài khoản người nhận (Collector)',
                    hintText: 'VD: 001234567890',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản nhận',
                    hintText: 'VD: NGUYEN VAN A',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Hướng dẫn cài đặt chia sẻ',
                    hintText: 'Nhập hướng dẫn bật chia sẻ thông báo trong app ngân hàng...',
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.apiClient.updateAdminBank(
                    code,
                    enabled: enabled,
                    receiverAccount: accountCtrl.text.trim(),
                    receiverName: nameCtrl.text.trim(),
                    instructions: instrCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadBanks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã cập nhật cấu hình cho ${code.toUpperCase()}')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lỗi: $error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadBanks, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: banks.length,
      itemBuilder: (ctx, idx) {
        final b = banks[idx];
        final code = (b['bank_code'] as String).toUpperCase();
        final enabled = b['enabled'] == true;
        final receiver = b['receiver_account'] as String?;
        final instructions = b['instructions'] as String?;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: enabled ? Colors.green.shade100 : Colors.grey.shade300,
              foregroundColor: enabled ? Colors.green.shade800 : Colors.grey.shade700,
              child: const Icon(Icons.account_balance),
            ),
            title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Trạng thái: ${enabled ? "Đang bật" : "Đã tắt"}'),
                if (receiver != null && receiver.isNotEmpty) Text('TK nhận: $receiver'),
                if (instructions != null && instructions.isNotEmpty)
                  Text(
                    'Hướng dẫn: $instructions',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Chỉnh sửa',
              onPressed: () => _editBank(b),
            ),
          ),
        );
      },
    );
  }
}
