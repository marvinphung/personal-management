import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UsersTab extends StatefulWidget {
  final ApiClient apiClient;

  const UsersTab({super.key, required this.apiClient});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserDto> users = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await widget.apiClient.listUsers();
      setState(() => users = list);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _approveUser(String userId) async {
    try {
      await widget.apiClient.approveUser(userId);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã phê duyệt người dùng thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _toggleCapture(String userId, bool enabled) async {
    try {
      await widget.apiClient.toggleCapture(userId, enabled);
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _generateTempPassword(String userId, String username) async {
    try {
      final tempPass = await widget.apiClient.setTemporaryPassword(userId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Mật khẩu tạm thời cho $username'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Người dùng sẽ bắt buộc phải đổi mật khẩu sau khi đăng nhập:'),
                const SizedBox(height: 12),
                SelectableText(
                  tempPass,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tempPass));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mật khẩu tạm thời vào clipboard')),
                  );
                },
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa tài khoản $username?'),
        content: const Text(
          'Tài khoản sẽ được chuyển vào mục "Tài khoản đã xóa". Dữ liệu và số tài khoản ngân hàng vẫn được bảo lưu, không thể đăng nhập hoặc nhận biến động mới.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.apiClient.deleteUser(userId);
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _restoreUser(String userId) async {
    try {
      await widget.apiClient.restoreUser(userId);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã khôi phục tài khoản thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _purgeUser(String userId, String username) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa vĩnh viễn $username?'),
        content: const Text(
          'CẢNH BÁO: Toàn bộ dữ liệu của người dùng này sẽ bị xóa hoàn toàn khỏi hệ thống và không thể khôi phục lại. Bạn có chắc chắn không?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade900),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.apiClient.purgeUser(userId);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa vĩnh viễn người dùng')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingUsers = users.where((u) => u.status == 'pending').toList();
    final activeUsers = users.where((u) => u.status == 'active').toList();
    final deletedUsers = users.where((u) => u.status == 'deleted').toList();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Chờ duyệt (${pendingUsers.length})'),
            Tab(text: 'Hoạt động (${activeUsers.length})'),
            Tab(text: 'Đã xóa (${deletedUsers.length})'),
          ],
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Pending Tab
              pendingUsers.isEmpty
                  ? const Center(child: Text('Không có tài khoản nào chờ duyệt'))
                  : ListView.builder(
                      itemCount: pendingUsers.length,
                      itemBuilder: (ctx, idx) {
                        final u = pendingUsers[idx];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_add)),
                          title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${u.id.substring(0, 8)}...'),
                          trailing: FilledButton(
                            onPressed: () => _approveUser(u.id),
                            child: const Text('Phê duyệt'),
                          ),
                        );
                      },
                    ),

              // 2. Active Tab
              activeUsers.isEmpty
                  ? const Center(child: Text('Chưa có người dùng hoạt động'))
                  : ListView.builder(
                      itemCount: activeUsers.length,
                      itemBuilder: (ctx, idx) {
                        final u = activeUsers[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(u.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    Switch(
                                      value: u.captureEnabled,
                                      onChanged: (val) => _toggleCapture(u.id, val),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Thu thập thông báo: ${u.captureEnabled ? "Bật" : "Tắt"}',
                                  style: TextStyle(color: u.captureEnabled ? Colors.green : Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.key, size: 16),
                                      label: const Text('Mật khẩu tạm'),
                                      onPressed: () => _generateTempPassword(u.id, u.username),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Xóa tài khoản',
                                      onPressed: () => _deleteUser(u.id, u.username),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              // 3. Deleted Tab
              deletedUsers.isEmpty
                  ? const Center(child: Text('Không có tài khoản nào đã xóa'))
                  : ListView.builder(
                      itemCount: deletedUsers.length,
                      itemBuilder: (ctx, idx) {
                        final u = deletedUsers[idx];
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person_off)),
                          title: Text(u.username, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                          subtitle: const Text('Đã lưu trữ dữ liệu'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _restoreUser(u.id),
                                child: const Text('Khôi phục'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: 'Xóa vĩnh viễn',
                                onPressed: () => _purgeUser(u.id, u.username),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
