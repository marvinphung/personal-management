import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

class SharingGuideScreen extends StatelessWidget {
  final BankSettingDto bank;

  const SharingGuideScreen({super.key, required this.bank});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hướng dẫn chia sẻ — ${bank.bankCode.toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tên ngân hàng: ${bank.receiverName ?? bank.bankCode.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (bank.receiverAccount != null) ...[
                      const SizedBox(height: 8),
                      Text('Tài khoản nhận: ${bank.receiverAccount}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cách bật chia sẻ thông báo biến động số dư:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                bank.instructions ?? 'Chưa có hướng dẫn từ quản trị viên.',
                style: const TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lưu ý: Quản lý Tao không kết nối trực tiếp đến ngân hàng hay can thiệp vào tài khoản của bạn. Ứng dụng chỉ nhận các thông báo biến động số dư được chia sẻ.',
              style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
