import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ManageMembersModal extends StatefulWidget {
  final int itineraryId;
  final String itineraryTitle;

  const ManageMembersModal({
    Key? key,
    required this.itineraryId,
    required this.itineraryTitle,
  }) : super(key: key);

  @override
  State<ManageMembersModal> createState() => _ManageMembersModalState();
}

class _ManageMembersModalState extends State<ManageMembersModal> {
  bool _isLoading = true;
  String _currentRole = 'VIEWER';
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseService().getItineraryMembers(widget.itineraryId);
    if (mounted) {
      if (data != null) {
        setState(() {
          _currentRole = data['currentRole'] ?? 'VIEWER';
          _members = data['members'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateRole(String targetUserId, String currentRole) async {
    final newRole = currentRole == 'EDITOR' ? 'VIEWER' : 'EDITOR';
    final success = await DatabaseService().updateMemberRole(
      widget.itineraryId,
      targetUserId,
      newRole,
    );
    if (success) {
      _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật quyền thành $newRole')),
        );
      }
    }
  }

  Future<void> _removeMember(String targetUserId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa thành viên "$name" khỏi chuyến đi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await DatabaseService().removeMember(
        widget.itineraryId,
        targetUserId,
      );
      if (success) {
        _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa thành viên khỏi chuyến đi')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentRole == 'OWNER';

    return Container(
      height: 480,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quản lý thành viên',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.itineraryTitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMembers,
              ),
            ],
          ),
          const Divider(height: 24),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_members.isEmpty)
            const Expanded(child: Center(child: Text('Chưa có thành viên nào.')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _members.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final member = _members[idx];
                  final role = member['role'];
                  final isMemberOwner = role == 'OWNER';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: (member['avatar'] != null &&
                                  member['avatar'].toString().startsWith('http'))
                              ? NetworkImage(member['avatar'])
                              : null,
                          child: (member['avatar'] == null ||
                                  !member['avatar'].toString().startsWith('http'))
                              ? Text((member['fullName'] ?? 'U')[0].toUpperCase())
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Text(
                          member['fullName'] ?? 'Người dùng',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Trực tuyến',
                            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      member['email'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMemberOwner
                                ? Colors.purple[50]
                                : role == 'EDITOR'
                                    ? Colors.blue[50]
                                    : Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMemberOwner
                                ? 'Chủ sở hữu'
                                : role == 'EDITOR'
                                    ? 'Chỉnh sửa'
                                    : 'Chỉ xem',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMemberOwner
                                  ? Colors.purple[700]
                                  : role == 'EDITOR'
                                      ? Colors.blue[700]
                                      : Colors.orange[800],
                            ),
                          ),
                        ),
                        if (isOwner && !isMemberOwner)
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'toggle_role') {
                                _updateRole(member['userId'], role);
                              } else if (val == 'remove') {
                                _removeMember(member['userId'], member['fullName'] ?? '');
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'toggle_role',
                                child: Text(
                                  role == 'EDITOR' ? 'Đổi thành Chỉ xem' : 'Đổi thành Chỉnh sửa',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Xóa khỏi chuyến đi', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
