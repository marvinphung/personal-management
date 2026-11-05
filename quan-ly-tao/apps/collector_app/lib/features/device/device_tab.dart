import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceTab extends StatefulWidget {
  final ApiClient apiClient;

  const DeviceTab({super.key, required this.apiClient});

  @override
  State<DeviceTab> createState() => _DeviceTabState();
}

class _DeviceTabState extends State<DeviceTab> {
  static const platform = MethodChannel('app.quanlytao.collector/status');

  int queueSize = 0;
  bool isPrimary = true;
  int collectorEpoch = 1;

  @override
  void initState() {
    super.initState();
    _checkQueue();
  }

  Future<void> _checkQueue() async {
    try {
      final res = await platform.invokeMethod<Map>('getCollectorHealth');
      if (res != null) {
        setState(() {
          queueSize = (res['queue_size'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _initiateHandover() async {
    await _checkQueue();

    if (!mounted) return;

    if (queueSize > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cảnh báo: Hàng đợi chưa xử lý hết'),
          content: Text(
            'Hiện tại máy này vẫn còn $queueSize thông báo biến động trong hàng đợi chưa được tải lên máy chủ thành công.\n\n'
            'Nếu kích hoạt máy mới ngay, các thông báo cũ còn kẹt trên máy này sẽ bị từ chối (do epoch đã tăng) và không thể bổ sung lại từ ngân hàng.\n\n'
            'Hãy chờ ứng dụng tự gửi hết hàng đợi trước khi kích hoạt máy mới.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy và chờ đồng bộ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bỏ qua & Chuyển giao ngay'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Handover confirmation
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận kích hoạt máy mới'),
        content: const Text(
          'Thao tác này sẽ tăng Collector Epoch trên máy chủ. Mọi máy thu thập cũ sẽ lập tức mất quyền tải lên dữ liệu để chống trùng lặp dữ liệu.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kích hoạt máy này'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã kích hoạt thiết bị này làm Collector chính')),
      );
      setState(() {
        isPrimary = true;
        collectorEpoch += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin thiết bị thu thập',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Vai trò máy thu thập'),
                  subtitle: Text(isPrimary ? 'Máy chính (Đang hoạt động)' : 'Máy dự phòng / Chưa kích hoạt'),
                  trailing: Chip(
                    label: Text('Epoch: $collectorEpoch'),
                    backgroundColor: Colors.blue.shade100,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Số thông báo trong hàng đợi cục bộ'),
                  subtitle: Text(
                    queueSize == 0
                        ? 'Đã tự động đồng bộ đầy đủ'
                        : '$queueSize thông báo đang tự động chờ gửi lại',
                  ),
                  trailing: queueSize == 0
                      ? const Icon(Icons.cloud_done, color: Colors.green)
                      : const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Text(
                      'Chuyển giao máy thu thập (Handover)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Khi đổi sang điện thoại Android thu thập mới:\n'
                  '1. Cài đặt Quản lý Tao — Máy chủ trên điện thoại mới.\n'
                  '2. Cài đặt và đăng nhập app ngân hàng, bật chia sẻ thông báo.\n'
                  '3. Cấp quyền Notification Listener trên máy mới.\n'
                  '4. Chờ hàng đợi trên máy cũ tự đồng bộ hết.\n'
                  '5. Nhấn nút kích hoạt dưới đây trên máy mới để nhận quyền chính thức.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF006C50)),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Kích hoạt chuyển giao cho máy này'),
                    onPressed: _initiateHandover,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
