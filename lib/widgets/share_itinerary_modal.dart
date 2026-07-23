import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';

class ShareItineraryModal extends StatefulWidget {
  final int itineraryId;
  final String itineraryTitle;

  const ShareItineraryModal({
    Key? key,
    required this.itineraryId,
    required this.itineraryTitle,
  }) : super(key: key);

  @override
  State<ShareItineraryModal> createState() => _ShareItineraryModalState();
}

class _ShareItineraryModalState extends State<ShareItineraryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _emailController = TextEditingController();
  bool _isSendingEmail = false;
  bool _isGeneratingLink = false;
  String? _shareUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

    final res = await DatabaseService().inviteByEmail(widget.itineraryId, email);

    setState(() => _isSendingEmail = false);

    if (mounted) {
      if (res != null && res['success'] == true) {
        _emailController.clear();
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

  Future<void> _fetchShareLink() async {
    if (_shareUrl != null) return;
    setState(() => _isGeneratingLink = true);

    final res = await DatabaseService().getShareLink(widget.itineraryId);

    setState(() => _isGeneratingLink = false);

    if (mounted && res != null && res['shareUrl'] != null) {
      setState(() {
        _shareUrl = res['shareUrl'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
          Text(
            'Chia sẻ chuyến đi',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.itineraryTitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF2563EB),
            onTap: (index) {
              if (index == 1) _fetchShareLink();
            },
            tabs: const [
              Tab(icon: Icon(Icons.email_outlined), text: 'Mời qua Email'),
              Tab(icon: Icon(Icons.link_rounded), text: 'Copy Link (Chỉ xem)'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Gửi Email (Chỉnh sửa)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mời thành viên cùng chỉnh sửa:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Nhập email người bạn muốn mời...',
                        prefixIcon: const Icon(Icons.mail_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '* Người được mời qua Email sẽ nhận được quyền CHỈNH SỬA chuyến đi.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSendingEmail ? null : _sendEmailInvite,
                        icon: _isSendingEmail
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_isSendingEmail ? 'Đang gửi...' : 'Gửi lời mời Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),

                // TAB 2: Copy Link / Social (Chỉ xem)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tạo link chia sẻ xem chuyến đi:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (_isGeneratingLink)
                      const Center(child: CircularProgressIndicator())
                    else if (_shareUrl != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _shareUrl!,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF2563EB)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _shareUrl!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã chép đường dẫn chia sẻ vào bộ nhớ tạm!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '* Người mở link này chỉ có quyền CHỈ XEM và có thể Sao chép chuyến đi về tài khoản riêng.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
