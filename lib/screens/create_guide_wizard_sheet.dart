import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class InvitedGuideCompanion {
  final String email;
  final String role; // 'VIEWER' | 'EDITOR'
  final String? fullName;
  final String? avatar;

  InvitedGuideCompanion({
    required this.email,
    required this.role,
    this.fullName,
    this.avatar,
  });
}

class CreateGuideWizardSheet extends StatefulWidget {
  final int userId;

  const CreateGuideWizardSheet({super.key, required this.userId});

  @override
  State<CreateGuideWizardSheet> createState() => _CreateGuideWizardSheetState();
}

class _CreateGuideWizardSheetState extends State<CreateGuideWizardSheet> {
  static const Color guidePrimary = Color(0xFFD97706); // Dark Warm Amber Gold Theme
  static const LinearGradient guideGradient = LinearGradient(
    colors: [Color(0xFF92400E), Color(0xFFD97706)],
  );

  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedDestination = '';

  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;

  // Companions & Privacy
  final List<InvitedGuideCompanion> _invitedCompanionsList = [];
  final TextEditingController _companionInputController = TextEditingController();
  String _dialogSelectedRole = 'VIEWER';
  String _privacyLevel = 'Công khai';

  // Categories
  List<Map<String, dynamic>> _dbCategories = [];
  bool _isLoadingCategories = false;
  final List<String> _selectedCategories = [];
  bool _includeTopAttractions = true;

  final List<Map<String, String>> _popularDestinations = [
    {'name': 'Cần Thơ', 'flag': '🇻🇳', 'desc': 'Thủ phủ miền Tây - Chợ nổi Cái Răng'},
    {'name': 'Đà Nẵng', 'flag': '🇻🇳', 'desc': 'Thành phố đáng sống - Cầu Rồng & Biển Mỹ Khê'},
    {'name': 'Hà Nội', 'flag': '🇻🇳', 'desc': 'Thủ đô ngàn năm văn hiến - Phố cổ & Hồ Gươm'},
    {'name': 'TP. Hồ Chí Minh', 'flag': '🇻🇳', 'desc': 'Thành phố sôi động - Sài Gòn rực rỡ'},
    {'name': 'Đà Lạt', 'flag': '🇻🇳', 'desc': 'Thành phố ngàn hoa - Khí hậu ôn hòa'},
    {'name': 'Phú Quốc', 'flag': '🇻🇳', 'desc': 'Đảo ngọc thiên đường - Bãi biển tuyệt đẹp'},
    {'name': 'Hội An', 'flag': '🇻🇳', 'desc': 'Phố cổ đèn lồng - Di sản thế giới'},
    {'name': 'Nha Trang', 'flag': '🇻🇳', 'desc': 'Vịnh biển xanh mát - VinWonders'},
    {'name': 'Vũng Tàu', 'flag': '🇻🇳', 'desc': 'Thành phố biển gần Sài Gòn'},
    {'name': 'Huế', 'flag': '🇻🇳', 'desc': 'Cố đô cổ kính - Sông Hương mộng mơ'},
    {'name': 'Sa Pa', 'flag': '🇻🇳', 'desc': 'Thành phố trong sương - Đỉnh Fansipan'},
    {'name': 'Ninh Bình', 'flag': '🇻🇳', 'desc': 'Tràng An - Ha Long trên cạn'},
  ];

  final List<Map<String, dynamic>> _defaultCategoriesData = [
    {'name': 'Nhà hàng', 'emoji': '🍽️', 'iconCode': 0xe532},
    {'name': 'Khách sạn', 'emoji': '🏨', 'iconCode': 0xe318},
    {'name': 'Quán ăn', 'emoji': '🍲', 'iconCode': 0xe57a},
    {'name': 'Cà phê', 'emoji': '☕', 'iconCode': 0xe395},
    {'name': 'Mua sắm', 'emoji': '🛍️', 'iconCode': 0xe59c},
    {'name': 'Công viên', 'emoji': '🌳', 'iconCode': 0xe4a1},
    {'name': 'Bảo tàng', 'emoji': '🏛️', 'iconCode': 0xe40a},
    {'name': 'Tham quan', 'emoji': '📸', 'iconCode': 0xe675},
    {'name': 'Check-in', 'emoji': '✨', 'iconCode': 0xe12b},
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _companionInputController.dispose();
    _pageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }



  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _searchDestination(query);
      } else {
        setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _searchDestination(String query) async {
    setState(() => _isLoadingSearch = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
      );
      final response = await http.get(url, headers: {'User-Agent': 'CloudMoodApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _searchResults = data is List ? data : []);
      }
    } catch (e) {
      debugPrint('Error searching: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  Future<void> _selectDestination(String destinationName) async {
    setState(() => _isSaving = true);
    final isSupported = await DatabaseService().isDestinationSupported(destinationName);
    setState(() => _isSaving = false);

    if (isSupported) {
      setState(() {
        _selectedDestination = destinationName;
        _searchResults = [];
        _searchController.clear();
      });
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.amber,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Chưa Hỗ Trợ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Rất tiếc, CloudMood hiện chưa hỗ trợ thiết lập hướng dẫn tại "$destinationName".\n\n'
              'Hãy thử trải nghiệm các địa điểm đã có sẵn dữ liệu của chúng tôi như: Cần Thơ, Đà Nẵng, Hà Nội, Hội An, Đà Lạt...',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Chọn địa điểm khác',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập tên bài hướng dẫn'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedDestination.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn điểm đến'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveGuide();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveGuide() async {
    if (_selectedDestination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn điểm đến'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSaving = true);
    final isSupported = await DatabaseService().isDestinationSupported(_selectedDestination);
    if (!isSupported) {
      setState(() => _isSaving = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.amber,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Chưa Hỗ Trợ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Rất tiếc, CloudMood hiện chưa hỗ trợ thiết lập hướng dẫn tại "$_selectedDestination".',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Chọn địa điểm khác',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final result = await DatabaseService().createUserItinerary(
        userId: widget.userId,
        title: _titleController.text.trim(),
        destination: _selectedDestination,
        startDate: DateTime.now(),
        days: 1,
        budget: 0,
        companion: _privacyLevel,
        pace: '',
        categories: _selectedCategories,
        amenities: [],
        isGuide: true,
      );

      if (mounted) {
        if (result != null) {
          final int? itineraryId = result['id'] is int
              ? result['id']
              : int.tryParse(result['id'].toString());

          if (itineraryId != null) {
            String privacyVal = 'public';
            if (_privacyLevel == 'Thành viên' || _privacyLevel == 'MEMBERS') privacyVal = 'members';
            if (_privacyLevel == 'Riêng tư' || _privacyLevel == 'PRIVATE') privacyVal = 'private';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('privacy_$itineraryId', privacyVal);
            result['companion'] = _privacyLevel;

            if (privacyVal == 'public') {
              try {
                await ApiClient.post('/explore/publish-itinerary/$itineraryId');
              } catch (_) {}
            } else {
              try {
                await ApiClient.post('/explore/unpublish-itinerary/$itineraryId');
              } catch (_) {}
            }

            if (_invitedCompanionsList.isNotEmpty) {
              for (final comp in _invitedCompanionsList) {
                await DatabaseService().inviteByEmail(
                  itineraryId,
                  comp.email,
                  role: comp.role,
                );
              }
            }
          }

          Navigator.of(context).pop(result);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tạo bài hướng dẫn và gửi lời mời thành công!'),
              backgroundColor: AppTheme.green,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo hướng dẫn thất bại. Vui lòng thử lại.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e'), behavior: SnackBarBehavior.fixed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddCompanionDialog() {
    _dialogSelectedRole = 'VIEWER';
    List<Map<String, dynamic>> suggestions = [];
    bool isSearching = false;
    String? emailErrorMessage;
    Timer? debounceTimer;
    Map<String, dynamic>? selectedUser;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: guidePrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: guidePrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mời đồng tác giả',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhập Email người nhận:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _companionInputController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: AppTheme.inputDecoration(
                          hintText: 'ví dụ: banbe@gmail.com',
                          prefixIcon: Icons.email_rounded,
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            emailErrorMessage = null;
                            selectedUser = null;
                          });
                          if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
                          if (val.trim().isEmpty) {
                            setDialogState(() {
                              suggestions = [];
                              isSearching = false;
                            });
                            return;
                          }
                          debounceTimer = Timer(const Duration(milliseconds: 300), () async {
                            final results = await DatabaseService().searchUsersByEmail(val.trim());
                            final alreadyInvited = _invitedCompanionsList.map((c) => c.email.toLowerCase()).toSet();
                            setDialogState(() {
                              suggestions = results.where((u) => !alreadyInvited.contains((u['email'] ?? '').toString().toLowerCase())).toList();
                              isSearching = false;
                            });
                          });
                        },
                      ),

                      // Suggestions list / Loading / Error alert
                      if (isSearching)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: guidePrimary),
                            ),
                          ),
                        )
                      else if (suggestions.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Material(
                              color: Colors.white,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: suggestions.length,
                                itemBuilder: (context, index) {
                                  final user = suggestions[index];
                                  final String fullName = user['fullName'] ?? 'Người dùng CloudMood';
                                  final String email = user['email'] ?? '';
                                  final String? avatar = user['avatar'];

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: guidePrimary.withOpacity(0.1),
                                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                                          ? NetworkImage(avatar)
                                          : null,
                                      child: (avatar == null || avatar.isEmpty)
                                          ? const Icon(Icons.person, size: 18, color: guidePrimary)
                                          : null,
                                    ),
                                    title: Text(
                                      fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      email,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                    onTap: () {
                                      setDialogState(() {
                                        _companionInputController.text = email;
                                        selectedUser = user;
                                        suggestions = [];
                                        emailErrorMessage = null;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                      if (emailErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  emailErrorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      Text(
                        'Đặt quyền hạn:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.subtitleText,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Role selector options
                      GestureDetector(
                        onTap: () {
                          setDialogState(() => _dialogSelectedRole = 'EDITOR');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _dialogSelectedRole == 'EDITOR'
                                ? guidePrimary.withOpacity(0.08)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _dialogSelectedRole == 'EDITOR'
                                  ? guidePrimary
                                  : Colors.grey[200]!,
                              width: _dialogSelectedRole == 'EDITOR' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: _dialogSelectedRole == 'EDITOR'
                                    ? guidePrimary
                                    : AppTheme.subtitleText,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chỉnh sửa (EDITOR)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Có thể xem, sửa bài viết và địa điểm',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.subtitleText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_dialogSelectedRole == 'EDITOR')
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: guidePrimary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: () {
                          setDialogState(() => _dialogSelectedRole = 'VIEWER');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _dialogSelectedRole == 'VIEWER'
                                ? guidePrimary.withOpacity(0.08)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _dialogSelectedRole == 'VIEWER'
                                  ? guidePrimary
                                  : Colors.grey[200]!,
                              width: _dialogSelectedRole == 'VIEWER' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 18,
                                color: _dialogSelectedRole == 'VIEWER'
                                    ? guidePrimary
                                    : AppTheme.subtitleText,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chỉ xem (VIEWER)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Chỉ được xem thông tin bài viết',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.subtitleText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_dialogSelectedRole == 'VIEWER')
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: guidePrimary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        onPressed: () {
                          _companionInputController.clear();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Hủy',
                          style: TextStyle(
                            color: AppTheme.subtitleText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: guidePrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final email = _companionInputController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() {
                              emailErrorMessage = 'Vui lòng nhập Email hợp lệ';
                            });
                            return;
                          }

                          final alreadyInvited = _invitedCompanionsList.any(
                            (c) => c.email.toLowerCase() == email.toLowerCase(),
                          );
                          if (alreadyInvited) {
                            setDialogState(() {
                              emailErrorMessage = 'Email này đã có trong danh sách';
                            });
                            return;
                          }

                          setState(() {
                            _invitedCompanionsList.add(
                              InvitedGuideCompanion(
                                email: email,
                                role: _dialogSelectedRole,
                                fullName: selectedUser?['fullName'],
                                avatar: selectedUser?['avatar'],
                              ),
                            );
                          });

                          _companionInputController.clear();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Thêm & Mời',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_currentStep > 0) {
                        _prevStep();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getStepTitleLabel(_currentStep),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: guidePrimary,
                              ),
                            ),
                            Text(
                              '${_currentStep + 1}/4',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(4, (index) {
                            final isActive = index <= _currentStep;
                            return Expanded(
                              child: Container(
                                height: 5,
                                margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                                decoration: BoxDecoration(
                                  color: isActive ? guidePrimary : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: AppTheme.subtitleText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step Content Pages (4 Steps, No Date Picker)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0Title(),
                  _buildStep1Destination(),
                  _buildStep2PrivacyCompanions(),
                  _buildStep3Categories(),
                ],
              ),
            ),

            // Bottom Actions Panel
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // STEP 0: Title Input
  Widget _buildStep0Title() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => guideGradient.createShader(bounds),
            child: const Text(
              'Bài viết hướng dẫn của bạn\nbắt đầu từ đây',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đặt một cái tên thật thu hút để chia sẻ kinh nghiệm du lịch quý báu.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Premium Input Field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: guidePrimary.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'VD: Kinh nghiệm du lịch Cần Thơ tự túc 2026...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.menu_book_rounded, color: guidePrimary, size: 22),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: guidePrimary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Suggestion chips header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: guidePrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: guidePrimary),
              ),
              const SizedBox(width: 8),
              Text(
                'Gợi ý tên hướng dẫn mẫu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.subtitleText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              '🚣 Cẩm nang Cần Thơ A-Z',
              '🍲 Tour Ẩm thực miền Tây',
              '📸 Top góc check-in Cần Thơ',
              '🎒 Phượt Cần Thơ 300k',
              '🏨 Đánh giá Khách sạn đẹp',
              '☕ Quán Cà phê chill nhất',
            ].map((suggestion) {
              final isSelected = _titleController.text == suggestion;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _titleController.text = suggestion;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? guidePrimary.withOpacity(0.08) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? guidePrimary : Colors.grey[200]!,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: guidePrimary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? guidePrimary : AppTheme.darkText,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 1: Destination Selection
  Widget _buildStep1Destination() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => guideGradient.createShader(bounds),
            child: const Text(
              'Hướng dẫn này dành cho đâu?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm: Cần Thơ, Đà Nẵng, Hà Nội...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15, fontStyle: FontStyle.italic),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.search_rounded, color: guidePrimary.withOpacity(0.6), size: 22),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: guidePrimary, width: 1.5),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 20, color: Colors.grey[400]),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _selectedDestination = '';
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          if (_isLoadingSearch) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator(color: guidePrimary)),
          ],

          // Search Autocomplete Results
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    final feature = _searchResults[index];
                    final address = feature['address'] ?? {};
                    final String name =
                        address['city'] ??
                        address['town'] ??
                        address['state'] ??
                        feature['name'] ??
                        feature['display_name']?.split(',').first ??
                        '';
                    final String formatted = feature['display_name'] ?? '';
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: guidePrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: guidePrimary, size: 20),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      subtitle: Text(
                        formatted,
                        style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _selectDestination(name);
                      },
                    );
                  },
                ),
              ),
            ),
          ] else if (!_isLoadingSearch) ...[
            const SizedBox(height: 20),
            // Popular Vietnam Destinations List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _popularDestinations.length,
              itemBuilder: (context, index) {
                final dest = _popularDestinations[index];
                final String name = dest['name']!;
                final String flag = dest['flag']!;
                final String desc = dest['desc'] ?? '';
                final isSelected = _selectedDestination == name;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDestination = name;
                      _searchController.text = name;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? guidePrimary.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? guidePrimary : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: guidePrimary.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? guidePrimary.withOpacity(0.12) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(flag, style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? guidePrimary : AppTheme.darkText,
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: guidePrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // STEP 2: Companions & Privacy Level
  Widget _buildStep2PrivacyCompanions() {
    final privacyOptions = [
      {'title': 'Công khai', 'desc': 'Mọi người đều có thể đọc bài hướng dẫn trên Khám phá', 'icon': Icons.public_rounded},
      {'title': 'Thành viên', 'desc': 'Chỉ bạn và người cùng biên soạn/đồng tác giả mới có thể xem', 'icon': Icons.group_rounded},
      {'title': 'Riêng tư', 'desc': 'Lưu nháp, chỉ mình bạn có quyền xem', 'icon': Icons.lock_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => guideGradient.createShader(bounds),
            child: const Text(
              'Quyền xem & Đồng tác giả',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Card 1: Co-authors / Companions Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: guidePrimary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: guidePrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Thêm đồng tác giả',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Mời bạn bè cùng viết bài hoặc đóng góp trải nghiệm cho bài hướng dẫn này.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Invited list chips
                if (_invitedCompanionsList.isNotEmpty) ...[
                  Column(
                    children: _invitedCompanionsList.map((companion) {
                      final isEditor = companion.role == 'EDITOR';
                      return Dismissible(
                        key: ValueKey(companion.email),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          setState(() {
                            _invitedCompanionsList.remove(companion);
                          });
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: guidePrimary,
                                backgroundImage: (companion.avatar != null && companion.avatar!.isNotEmpty)
                                    ? NetworkImage(companion.avatar!)
                                    : null,
                                child: (companion.avatar == null || companion.avatar!.isEmpty)
                                    ? const Icon(Icons.person_rounded, size: 18, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (companion.fullName != null && companion.fullName!.isNotEmpty)
                                      Text(
                                        companion.fullName!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    Text(
                                      companion.email,
                                      style: TextStyle(
                                        fontSize: companion.fullName != null ? 11 : 13,
                                        color: companion.fullName != null ? Colors.grey[600] : AppTheme.darkText,
                                        fontWeight: companion.fullName != null ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isEditor ? guidePrimary.withOpacity(0.1) : Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isEditor ? 'Viết bài' : 'Chỉ xem',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEditor ? guidePrimary : Colors.amber[800],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _invitedCompanionsList.remove(companion);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // + Button
                GestureDetector(
                  onTap: _showAddCompanionDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: guideGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: guidePrimary.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Thêm Email đồng tác giả',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card 2: Privacy Level Radio Cards
          Text(
            'Mức độ hiển thị hướng dẫn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: privacyOptions.map((opt) {
              final String title = opt['title'] as String;
              final String desc = opt['desc'] as String;
              final IconData icon = opt['icon'] as IconData;
              final isSelected = _privacyLevel == title;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _privacyLevel = title;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? guidePrimary : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: guidePrimary.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? guidePrimary.withOpacity(0.1) : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected ? guidePrimary : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? guidePrimary : AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? guidePrimary : Colors.grey[300]!,
                            width: isSelected ? 6 : 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // STEP 3: Categories & Topics
  Widget _buildStep3Categories() {
    final categoriesListToDisplay = _dbCategories.isNotEmpty ? _dbCategories : _defaultCategoriesData;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => guideGradient.createShader(bounds),
            child: const Text(
              'Chủ đề hướng dẫn',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn các danh mục phù hợp để giúp mọi người dễ dàng tìm thấy hướng dẫn của bạn.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Feature Card: Top Rated Attractions Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  guidePrimary.withOpacity(0.08),
                  const Color(0xFFFFFBEB),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: guidePrimary.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: guidePrimary.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: const Text('⭐', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Địa điểm hàng đầu (⭐ 4.0+)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: guidePrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ưu tiên gợi ý các điểm tham quan được đánh giá cao nhất',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _includeTopAttractions,
                  activeColor: guidePrimary,
                  onChanged: (val) {
                    setState(() {
                      _includeTopAttractions = val;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Chủ đề trọng tâm:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 14),

          // Categories Selection Grid
          if (_isLoadingCategories)
            const Center(child: CircularProgressIndicator(color: guidePrimary))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categoriesListToDisplay.map((cat) {
                final String name = cat['name'];
                final isSelected = _selectedCategories.contains(name);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.remove(name);
                      } else {
                        _selectedCategories.add(name);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected ? guideGradient : null,
                      color: isSelected ? null : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(30),
                      border: isSelected ? null : Border.all(color: Colors.grey[200]!),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: guidePrimary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCategoryLeading(cat),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.darkText,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // BOTTOM NAVIGATION BAR
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient Primary Action Button
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: _isSaving ? null : guideGradient,
              color: _isSaving ? Colors.grey[300] : null,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: guidePrimary.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _isSaving ? null : _nextStep,
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Row(
                            key: ValueKey<int>(_currentStep),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getPrimaryButtonText(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentStep == 3 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Secondary Text Button
          if (_currentStep == 2) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                _nextStep();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Bỏ qua bước này',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryLeading(dynamic cat) {
    if (cat is Map<String, dynamic>) {
      final int? iconCode = cat['iconCode'] != null
          ? (cat['iconCode'] is int ? cat['iconCode'] : int.tryParse(cat['iconCode'].toString()))
          : null;

      if (iconCode != null && iconCode > 0) {
        return Icon(
          IconData(iconCode, fontFamily: 'MaterialIcons'),
          size: 18,
          color: guidePrimary,
        );
      }

      final String name = (cat['name'] ?? '').toString().toLowerCase();
      if (cat['emoji'] != null && cat['emoji'].toString().isNotEmpty && cat['emoji'] != '📍') {
        return Text(cat['emoji'].toString(), style: const TextStyle(fontSize: 18));
      }

      if (name.contains('nhà hàng')) return const Icon(Icons.restaurant_rounded, size: 18, color: guidePrimary);
      if (name.contains('khách sạn')) return const Icon(Icons.hotel_rounded, size: 18, color: guidePrimary);
      if (name.contains('quán ăn')) return const Icon(Icons.fastfood_rounded, size: 18, color: guidePrimary);
      if (name.contains('cà phê') || name.contains('cafe')) return const Icon(Icons.local_cafe_rounded, size: 18, color: guidePrimary);
      if (name.contains('trung tâm thương mại') || name.contains('mua sắm')) return const Icon(Icons.shopping_bag_rounded, size: 18, color: guidePrimary);
      if (name.contains('công viên') || name.contains('thiên nhiên')) return const Icon(Icons.park_rounded, size: 18, color: guidePrimary);
      if (name.contains('bảo tàng') || name.contains('văn hóa')) return const Icon(Icons.museum_rounded, size: 18, color: guidePrimary);
      if (name.contains('điểm tham quan') || name.contains('tham quan')) return const Icon(Icons.tour_rounded, size: 18, color: guidePrimary);
      if (name.contains('trường học')) return const Icon(Icons.school_rounded, size: 18, color: guidePrimary);
      if (name.contains('bar') || name.contains('đêm')) return const Icon(Icons.local_bar_rounded, size: 18, color: guidePrimary);
      if (name.contains('check-in') || name.contains('sống ảo')) return const Icon(Icons.camera_alt_rounded, size: 18, color: guidePrimary);
    }
    return const Icon(Icons.location_on_rounded, size: 18, color: guidePrimary);
  }

  String _getStepTitleLabel(int step) {
    switch (step) {
      case 0:
        return 'Tên hướng dẫn';
      case 1:
        return 'Điểm đến';
      case 2:
        return 'Quyền xem';
      case 3:
        return 'Chủ đề';
      default:
        return '';
    }
  }

  String _getPrimaryButtonText() {
    switch (_currentStep) {
      case 0:
      case 1:
        return 'Tiếp tục';
      case 2:
        return 'Mời đồng tác giả';
      case 3:
        return 'Hoàn tất & Tạo hướng dẫn';
      default:
        return 'Tiếp tục';
    }
  }
}
