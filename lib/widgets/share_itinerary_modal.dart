import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ShareItineraryModal extends StatefulWidget {
  final int itineraryId;
  final String itineraryTitle;

  const ShareItineraryModal({
    super.key,
    required this.itineraryId,
    required this.itineraryTitle,
  });

  @override
  State<ShareItineraryModal> createState() => _ShareItineraryModalState();
}

class _ShareItineraryModalState extends State<ShareItineraryModal> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSendingEmail = false;
  String _selectedRole = 'EDITOR'; // 'EDITOR' hoặc 'VIEWER'

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ Email hợp lệ.')),
      );
      return;
    }

    setState(() => _isSendingEmail = true);

    final res = await DatabaseService().inviteByEmail(
      widget.itineraryId,
      email,
      role: _selectedRole,
    );

    setState(() => _isSendingEmail = false);

    if (mounted) {
      if (res != null && res['success'] == true) {
        _emailController.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Đã gửi lời mời qua email thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['message'] ?? 'Gửi lời mời thất bại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mail_outline_rounded, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mời tham gia chuyến đi',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        widget.itineraryTitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nhập Email
            const Text(
              'Địa chỉ Email người nhận:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Nhập email người bạn muốn mời...',
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2563EB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 18),

            // Chọn Quyền (Role)
            const Text(
              'Quyền hạn tham gia:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF8FAFC),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedRole = 'EDITOR'),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            _selectedRole == 'EDITOR' ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: const Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF2563EB)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Có thể chỉnh sửa (Editor)',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Người được mời có thể thêm, sửa, xóa địa điểm trong lịch trình.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  InkWell(
                    onTap: () => setState(() => _selectedRole = 'VIEWER'),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            _selectedRole == 'VIEWER' ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: const Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0EA5E9)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Chỉ xem (Viewer)',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Người được mời chỉ xem được nội dung chuyến đi mà không thể chỉnh sửa.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nút Gửi Lời Mời
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSendingEmail ? null : _sendEmailInvite,
                icon: _isSendingEmail
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSendingEmail ? 'Đang gửi...' : 'Gửi lời mời Email',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
