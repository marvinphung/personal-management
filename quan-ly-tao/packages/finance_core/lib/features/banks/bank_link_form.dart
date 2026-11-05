import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class BankLinkForm extends ConsumerStatefulWidget {
  final BankBindingDto? existingBinding;
  final VoidCallback onSaved;

  const BankLinkForm({super.key, this.existingBinding, required this.onSaved});

  @override
  ConsumerState<BankLinkForm> createState() => _BankLinkFormState();
}

class _BankLinkFormState extends ConsumerState<BankLinkForm> {
  final _accountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedBank = 'bidv';
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, String> _supportedBanks = const {
    'bidv': 'BIDV (Ngân hàng Đầu tư và Phát triển)',
    'vietinbank': 'VietinBank (Ngân hàng Công Thương)',
    'vietcombank': 'Vietcombank (Ngân hàng Ngoại Thương)',
    'techcombank': 'Techcombank (Ngân hàng Kỹ Thương)',
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingBinding != null) {
      _selectedBank = widget.existingBinding!.bankCode;
      _accountController.text = widget.existingBinding!.accountNumber;
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = ref.read(apiClientProvider);

    try {
      if (widget.existingBinding != null) {
        await api.updateBankBinding(
          widget.existingBinding!.id,
          _accountController.text.trim(),
        );
      } else {
        await api.createBankBinding(
          _selectedBank,
          _accountController.text.trim(),
        );
      }
      widget.onSaved();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối máy chủ. Vui lòng kiểm tra mạng.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBinding != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Đổi số tài khoản ngân hàng' : 'Liên kết tài khoản ngân hàng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!isEditing) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(
                  labelText: 'Ngân hàng',
                  border: OutlineInputBorder(),
                ),
                items: _supportedBanks.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBank = v);
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tài khoản của bạn',
                hintText: 'Nhập đầy đủ số tài khoản (giữ nguyên số 0 đầu)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập số tài khoản';
                }
                if (v.trim().length < 4) {
                  return 'Số tài khoản quá ngắn';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Cập nhật' : 'Liên kết ngay'),
            ),
          ],
        ),
      ),
    );
  }
}
