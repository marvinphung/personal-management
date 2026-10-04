import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  static const platform = MethodChannel('app.quanlytao.collector/status');

  bool permissionGranted = false;
  bool listenerConnected = false;
  bool backendConfigured = false;
  bool credentialConfigured = false;
  int queueSize = 0;
  String? latestReceiveTime;
  String? latestUploadTime;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => checking = true);
    try {
      final res = await platform.invokeMethod<Map>('getCollectorHealth');
      if (res != null) {
        setState(() {
          permissionGranted = res['permission_granted'] == true;
          listenerConnected = res['listener_connected'] == true;
          backendConfigured = res['backend_configured'] == true;
          credentialConfigured = res['credential_configured'] == true;
          queueSize = (res['queue_size'] as num?)?.toInt() ?? 0;
          latestReceiveTime = res['latest_receive_time'] as String?;
          latestUploadTime = res['latest_upload_time'] as String?;
        });
      }
    } catch (_) {
      setState(() {
        permissionGranted = false;
        listenerConnected = false;
        backendConfigured = false;
        credentialConfigured = false;
        queueSize = 0;
      });
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _reconnectListener() async {
    try {
      await platform.invokeMethod('reconnectListener');
      await _refreshStatus();
    } catch (_) {}
  }

  Future<void> _openSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (_) {}
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
                  'Quyền truy cập thông báo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    permissionGranted ? Icons.check_circle : Icons.error_outline,
                    color: permissionGranted ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Quyền Notification Listener'),
                  subtitle: Text(permissionGranted ? 'Đã cấp quyền' : 'Chưa cấp quyền'),
                  trailing: !permissionGranted
                      ? ElevatedButton(
                          onPressed: _openSettings,
                          child: const Text('Cấp quyền'),
                        )
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    listenerConnected ? Icons.link : Icons.link_off,
                    color: listenerConnected ? Colors.green : Colors.red,
                  ),
                  title: const Text('Trạng thái kết nối dịch vụ'),
                  subtitle: Text(listenerConnected ? 'Dịch vụ đang chạy và kết nối' : 'Dịch vụ bị ngắt'),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kết nối lại'),
                    onPressed: _reconnectListener,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  backendConfigured ? Icons.cloud_done : Icons.cloud_off,
                  color: backendConfigured ? Colors.green : Colors.red,
                ),
                title: const Text('Máy chủ HTTPS'),
                subtitle: Text(backendConfigured ? 'Đã cấu hình' : 'Chưa cấu hình'),
              ),
              ListTile(
                leading: Icon(
                  credentialConfigured ? Icons.verified_user : Icons.gpp_bad,
                  color: credentialConfigured ? Colors.green : Colors.red,
                ),
                title: const Text('Thông tin xác thực Collector'),
                subtitle: Text(
                  credentialConfigured
                      ? 'Đã cấu hình'
                      : 'Chưa được server cấp credential; hàng đợi chưa thể tải lên',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hàng đợi tải lên máy chủ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.queue),
                  title: const Text('Số thông báo đang chờ tải lên'),
                  trailing: Chip(
                    label: Text(
                      '$queueSize',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: queueSize > 0 ? Colors.amber.shade200 : Colors.green.shade100,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Thời gian nhận gần nhất'),
                  subtitle: Text(latestReceiveTime ?? 'Chưa có thông báo nào'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Thời gian gửi thành công gần nhất'),
                  subtitle: Text(latestUploadTime ?? 'Chưa gửi payload nào'),
                ),
                const Divider(),
                Text(
                  'Bảo mật: Màn hình này không lưu trữ hay hiển thị chi tiết số tiền hoặc nội dung giao dịch ngân hàng.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: checking ? null : _refreshStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Làm mới trạng thái'),
          ),
        ),
      ],
    );
  }
}
