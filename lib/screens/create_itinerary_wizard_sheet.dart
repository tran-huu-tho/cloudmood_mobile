import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class InvitedCompanion {
  final String email;
  final String role; // 'EDITOR' or 'VIEWER'
  final String? fullName;
  final String? avatar;

  InvitedCompanion({
    required this.email,
    required this.role,
    this.fullName,
    this.avatar,
  });
}

class CreateItineraryWizardSheet extends StatefulWidget {
  final int userId;

  const CreateItineraryWizardSheet({super.key, required this.userId});

  @override
  State<CreateItineraryWizardSheet> createState() =>
      _CreateItineraryWizardSheetState();
}

class _CreateItineraryWizardSheetState
    extends State<CreateItineraryWizardSheet> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 0: Trip Name
  final _tripTitleController = TextEditingController();

  // Step 1: Destination (Vietnam Only, Can Tho pinned at top)
  final _searchController = TextEditingController();
  String _selectedDestination = '';
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;

  // Only Vietnam Destinations - Cần Thơ pinned first
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

  // Step 2: Date selection (Smart 3-date shift & reverse selection)
  DateTimeRange? _selectedDateRange;
  DateTime? _lastTappedDate;
  int _days = 3;
  late final ScrollController _calendarScrollController = ScrollController(
    initialScrollOffset: 4310.0,
  );
  final GlobalKey _selectedDateKey = GlobalKey();
  final GlobalKey _currentMonthKey = GlobalKey();

  void _scrollToSelectedDate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDateKey.currentContext != null) {
        Scrollable.ensureVisible(
          _selectedDateKey.currentContext!,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: 0.3,
        );
      } else if (_currentMonthKey.currentContext != null) {
        Scrollable.ensureVisible(
          _currentMonthKey.currentContext!,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  // Step 3: Companions & Privacy (Email invites with role permissions)
  final List<InvitedCompanion> _invitedCompanionsList = [];
  final TextEditingController _companionInputController = TextEditingController();
  String _dialogSelectedRole = 'EDITOR'; // 'EDITOR' or 'VIEWER'
  String _privacyLevel = 'Riêng tư'; // 'Riêng tư', 'Thành viên'

  // Step 4: Trip Preferences (DB Categories, Top Rated Attractions, UI)
  List<Map<String, dynamic>> _dbCategories = [];
  bool _isLoadingCategories = false;
  final List<String> _selectedCategories = [];
  final List<String> _selectedSubCategories = [];
  bool _includeTopAttractions = true;
  bool _learnFromPastTrips = false;
  List<Map<String, dynamic>> _topRatedPlacesPreview = [];
  bool _isLoadingTopPlaces = false;

  final List<Map<String, dynamic>> _defaultCategoriesData = [
    {
      'name': 'Điểm tham quan hàng đầu',
      'emoji': '🗽',
      'subCategories': [
        'Di tích lịch sử',
        'Kiến trúc nổi tiếng',
        'Điểm ngắm cảnh',
        'Địa danh biểu tượng',
      ],
    },
    {
      'name': 'Ẩm thực & đồ uống',
      'emoji': '🍧',
      'subCategories': [
        'Đặc sản địa phương',
        'Ăn vặt đường phố',
        'Nhà hàng cao cấp',
        'Hải sản tươi sống',
        'Quán nướng & BBQ',
      ],
    },
    {
      'name': 'Bảo tàng & văn hóa',
      'emoji': '🏛',
      'subCategories': [
        'Bảo tàng nghệ thuật',
        'Trung tâm văn hóa',
        'Nhà hát & Biểu diễn',
        'Làng nghề truyền thống',
      ],
    },
    {
      'name': 'Công viên & thiên nhiên',
      'emoji': '🌲',
      'subCategories': [
        'Bãi biển & Đảo',
        'Vườn quốc gia',
        'Núi đồi & Thác nước',
        'Công viên cây xanh',
      ],
    },
    {
      'name': 'Mua sắm',
      'emoji': '🛍',
      'subCategories': [
        'Chợ đêm',
        'Trung tâm thương mại',
        'Đặc sản làm quà',
        'Phố mua sắm',
      ],
    },
    {
      'name': 'Quán bar & cuộc sống về đêm',
      'emoji': '🍸',
      'subCategories': [
        'Rooftop Bar',
        'Pub & Beer garden',
        'Câu lạc bộ đêm',
        'Phố đi bộ',
      ],
    },
    {
      'name': 'Thư giãn / Cafe',
      'emoji': '☕',
      'subCategories': [
        'Quán cafe sống ảo',
        'Spa & Massage',
        'Trà chiều',
        'Khu nghỉ dưỡng',
      ],
    },
    {
      'name': 'Check-in sống ảo',
      'emoji': '📸',
      'subCategories': [
        'Cầu check-in',
        'Góc ngắm hoàng hôn',
        'Phố cổ',
        'Vườn hoa',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDateRange = DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 2)),
    );
    _lastTappedDate = today.add(const Duration(days: 2));
    _days = 3;
    _fetchCategoriesFromDb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  void dispose() {
    _tripTitleController.dispose();
    _searchController.dispose();
    _companionInputController.dispose();
    _pageController.dispose();
    _calendarScrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCategoriesFromDb() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await DatabaseService().getCategories();
      if (categories.isNotEmpty) {
        setState(() {
          _dbCategories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error fetching DB categories: $e');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchTopRatedPlaces(String destination) async {
    if (destination.isEmpty) return;
    setState(() => _isLoadingTopPlaces = true);
    try {
      final places = await DatabaseService().searchPlaces(
        destination: destination,
        minRating: 4.0,
      );
      setState(() {
        _topRatedPlacesPreview = places.take(6).toList();
      });
    } catch (e) {
      debugPrint('Error fetching top rated places: $e');
    } finally {
      setState(() => _isLoadingTopPlaces = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().isNotEmpty) {
        _searchDestination(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchDestination(String query) async {
    setState(() => _isLoadingSearch = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$query, Vietnam')}&format=json&addressdetails=1&limit=5',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'CloudMoodApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data is List ? data : [];
        });
      }
    } catch (e) {
      debugPrint('Error searching destination: $e');
    } finally {
      setState(() => _isLoadingSearch = false);
    }
  }

  void _showUnsupportedDestinationDialog(String destinationName) {
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
              size: 26,
            ),
            SizedBox(width: 8),
            Text(
              'Địa điểm chưa hỗ trợ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Rất tiếc, CloudMood hiện chưa có dữ liệu địa điểm tại "$destinationName".\n\n'
          'Vui lòng chọn các địa điểm Việt Nam đã hỗ trợ như: Cần Thơ, Đà Nẵng, Hà Nội, Hội An, Đà Lạt, Phú Quốc, TP. Hồ Chí Minh...',
          style: const TextStyle(fontSize: 14, height: 1.4),
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

  Future<void> _selectDestination(String destinationName) async {
    setState(() => _isSaving = true);
    final isSupported = await DatabaseService().isDestinationSupported(
      destinationName,
    );
    setState(() => _isSaving = false);

    if (isSupported) {
      setState(() {
        _selectedDestination = destinationName;
        _searchController.text = destinationName;
        _searchResults = [];
        if (_tripTitleController.text.trim().isEmpty) {
          _tripTitleController.text = 'Khám phá $destinationName';
        }
      });
      _fetchTopRatedPlaces(destinationName);
      _nextStep();
    } else {
      if (mounted) {
        _showUnsupportedDestinationDialog(destinationName);
      }
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      // Step 0: Trip Name
      if (_tripTitleController.text.trim().isEmpty) {
        _tripTitleController.text = 'Hành trình của tôi';
      }
    } else if (_currentStep == 1) {
      // Step 1: Destination
      final targetDest = _selectedDestination.isNotEmpty
          ? _selectedDestination
          : _searchController.text.trim();

      if (targetDest.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn điểm đến chuyến đi!')),
        );
        return;
      }

      setState(() => _isSaving = true);
      final isSupported = await DatabaseService().isDestinationSupported(targetDest);
      setState(() => _isSaving = false);

      if (!isSupported) {
        if (mounted) {
          _showUnsupportedDestinationDialog(targetDest);
        }
        return;
      }

      setState(() {
        _selectedDestination = targetDest;
        if (_tripTitleController.text.trim().isEmpty) {
          _tripTitleController.text = 'Khám phá $targetDest';
        }
      });
      _fetchTopRatedPlaces(_selectedDestination);
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (_currentStep == 2) {
        _scrollToSelectedDate();
      }
    } else {
      _saveItinerary();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Date selection logic: Shift Day 1 -> Day 3 -> Day 9 & Reverse Selection Support (27 -> 25 -> 23 = 23-25) & Max 30 days limit
  void _onDateCellTapped(DateTime cellDate) {
    setState(() {
      if (_selectedDateRange == null || _lastTappedDate == null) {
        _selectedDateRange = DateTimeRange(start: cellDate, end: cellDate);
        _lastTappedDate = cellDate;
      } else {
        final anchor = _lastTappedDate!;
        DateTime newStart;
        DateTime newEnd;

        if (cellDate.isBefore(anchor)) {
          newStart = cellDate;
          newEnd = anchor;
        } else {
          newStart = anchor;
          newEnd = cellDate;
        }

        // Enforce 30 days maximum trip duration
        int diffDays = newEnd.difference(newStart).inDays + 1;
        if (diffDays > 30) {
          if (cellDate.isBefore(anchor)) {
            newStart = anchor.subtract(const Duration(days: 29));
          } else {
            newEnd = anchor.add(const Duration(days: 29));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('CloudMood hỗ trợ tạo chuyến đi tối đa 30 ngày.'),
                backgroundColor: AppTheme.amber,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        _selectedDateRange = DateTimeRange(start: newStart, end: newEnd);
        _lastTappedDate = cellDate;
      }
      _days = _selectedDateRange!.end.difference(_selectedDateRange!.start).inDays + 1;
    });
  }

  Future<void> _saveItinerary() async {
    setState(() => _isSaving = true);
    try {
      final combinedCategories = [
        ..._selectedCategories,
        ..._selectedSubCategories,
      ];
      if (_includeTopAttractions &&
          !combinedCategories.contains('Điểm tham quan hàng đầu')) {
        combinedCategories.add('Điểm tham quan hàng đầu');
      }

      final String title = _tripTitleController.text.trim().isNotEmpty
          ? _tripTitleController.text.trim()
          : 'Khám phá $_selectedDestination';

      final result = await DatabaseService().createUserItinerary(
        userId: widget.userId,
        title: title,
        destination: _selectedDestination,
        startDate: _selectedDateRange?.start ?? DateTime.now(),
        days: _days,
        budget: 0,
        companion: _privacyLevel,
        pace: 'Balanced',
        categories: combinedCategories,
        amenities: [],
      );

      if (mounted) {
        if (result != null) {
          final int itineraryId = (result['id'] is int)
              ? result['id']
              : int.tryParse(result['id'].toString()) ?? 0;

          if (itineraryId > 0) {
            final prefs = await SharedPreferences.getInstance();
            String privacyVal = 'private';
            if (_privacyLevel == 'Thành viên' || _privacyLevel == 'MEMBERS') privacyVal = 'members';
            await prefs.setString('privacy_$itineraryId', privacyVal);
            result['companion'] = _privacyLevel;

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
              content: Text('Đã tạo lịch trình và gửi lời mời thành công!'),
              backgroundColor: AppTheme.green,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo hành trình thất bại. Vui lòng thử lại.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAddCompanionDialog() {
    _dialogSelectedRole = 'EDITOR';
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
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mời bạn đồng hành',
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                                        ? NetworkImage(avatar)
                                        : null,
                                    child: (avatar == null || avatar.isEmpty)
                                        ? const Icon(Icons.person, size: 18, color: AppTheme.primary)
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
                              ? AppTheme.primary.withOpacity(0.08)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _dialogSelectedRole == 'EDITOR'
                                ? AppTheme.primary
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
                                  ? AppTheme.primary
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
                                    'Có thể xem, sửa lịch trình và địa điểm',
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
                                color: AppTheme.primary,
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
                              ? AppTheme.primary.withOpacity(0.08)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _dialogSelectedRole == 'VIEWER'
                                ? AppTheme.primary
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
                                  ? AppTheme.primary
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
                                    'Chỉ được xem thông tin chuyến đi',
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
                                color: AppTheme.primary,
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
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final emailText = _companionInputController.text.trim();
                          if (emailText.isEmpty) {
                            setDialogState(() => emailErrorMessage = 'Vui lòng nhập Email');
                            return;
                          }

                          // Check if user is already added to companion list
                          final isAlreadyAdded = _invitedCompanionsList.any(
                            (c) => c.email.toLowerCase() == emailText.toLowerCase(),
                          );
                          if (isAlreadyAdded) {
                            setDialogState(() {
                              emailErrorMessage = 'Người dùng này đã có trong danh sách bạn đồng hành';
                            });
                            return;
                          }

                          // Verify if email belongs to a registered CloudMood user
                          setDialogState(() => emailErrorMessage = null);
                          final searchResult = await DatabaseService().searchUsersByEmail(emailText);
                          final exactUser = searchResult.firstWhere(
                            (u) => (u['email'] ?? '').toString().toLowerCase() == emailText.toLowerCase(),
                            orElse: () => selectedUser ?? {},
                          );

                          if (exactUser.isEmpty) {
                            setDialogState(() {
                              emailErrorMessage = 'Email chưa đăng ký tài khoản CloudMood';
                            });
                            return;
                          }

                          setState(() {
                            _invitedCompanionsList.add(
                              InvitedCompanion(
                                email: exactUser['email'] ?? emailText,
                                role: _dialogSelectedRole,
                                fullName: exactUser['fullName'],
                                avatar: exactUser['avatar'],
                              ),
                            );
                          });
                          _companionInputController.clear();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Thêm & Mời',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Premium Top Navigation Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primary.withOpacity(0.06),
                    width: 1,
                  ),
                ),
              ),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey[50]!, Colors.grey[100]!],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.darkText),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _getStepTitleLabel(_currentStep),
                                key: ValueKey<int>(_currentStep),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentStep + 1}/5',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            final isActive = index <= _currentStep;
                            final isCurrent = index == _currentStep;
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                height: isCurrent ? 6 : 4,
                                margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? const LinearGradient(
                                          colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                                        )
                                      : null,
                                  color: isActive ? null : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primary.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 20, color: AppTheme.subtitleText),
                    ),
                  ),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0TripName(),
                  _buildStep1Destination(),
                  _buildStep2Dates(),
                  _buildStep3Companions(),
                  _buildStep4Interests(),
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



  // STEP 0: Trip Name Input — Premium Hero Title + Animated Suggestions
  Widget _buildStep0TripName() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Hero gradient title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
            ).createShader(bounds),
            child: const Text(
              'Hành trình của bạn\nbắt đầu từ đây',
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
            'Đặt một cái tên thật ý nghĩa để ghi dấu những kỷ niệm đẹp.',
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
                  color: AppTheme.primary.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _tripTitleController,
              autofocus: true,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Chuyến đi Cần Thơ rực rỡ, Hè 2026...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.card_travel_rounded, color: AppTheme.primary, size: 22),
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
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
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
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'Gợi ý tên chuyến đi mẫu',
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
              '🚣 Khám phá Cần Thơ',
              '🌴 Chuyến đi Mùa Hè 2026',
              '🏖️ Du lịch Nghỉ dưỡng',
              '🍲 Tour Ẩm thực miền Tây',
              '🎒 Phượt cùng Bạn bè',
              '☕ Tour Cà phê & Chill',
            ].map((suggestion) {
              final isSelected = _tripTitleController.text == suggestion;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _tripTitleController.text = suggestion;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withOpacity(0.08) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.grey[200]!,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.1),
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
                      color: isSelected ? AppTheme.primary : AppTheme.darkText,
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

  // STEP 1: Destination Selection (Vietnam Only, Can Tho Pinned First)
  Widget _buildStep1Destination() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
            ).createShader(bounds),
            child: const Text(
              'Bạn đang đi đâu?',
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
                  child: Icon(Icons.search_rounded, color: AppTheme.primary.withOpacity(0.6), size: 22),
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
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
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
            const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
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
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey[100]),
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
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 20),
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
            // Popular Vietnam Destinations List (Clean Vertical List View)
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.1),
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
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.12)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            flag,
                            style: const TextStyle(fontSize: 22),
                          ),
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.darkText,
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
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

  // STEP 2: Date Picker — Premium Fluid Calendar
  Widget _buildStep2Dates() {
    final now = DateTime.now();

    final monthsList = List.generate(25, (index) {
      final monthOffset = index - 12;
      return DateTime(now.year, now.month + monthOffset, 1);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sticky Header Bar: Title + Date Range Banner + Quick Presets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                ).createShader(bounds),
                child: const Text(
                  'Chọn ngày khởi hành',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Premium Date range summary banner
              if (_selectedDateRange != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.08),
                        const Color(0xFFEFF6FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tổng thời gian: $_days ngày',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Quick Duration Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickPresetChip('⚡ Cuối tuần (2N)', 2),
                    const SizedBox(width: 8),
                    _buildQuickPresetChip('⛵ 3 Ngày 2 Đêm', 3),
                    const SizedBox(width: 8),
                    _buildQuickPresetChip('🌴 5 Ngày', 5),
                    const SizedBox(width: 8),
                    _buildQuickPresetChip('🎒 1 Tuần (7N)', 7),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),

        // Scrollable Calendar Area (25 Months)
        Expanded(
          child: ListView.builder(
            controller: _calendarScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: monthsList.length,
            itemBuilder: (context, index) {
              final monthDate = monthsList[index];
              final isCurrentMonth = monthDate.year == now.year && monthDate.month == now.month;
              return Padding(
                key: isCurrentMonth ? _currentMonthKey : null,
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildMonthGrid(monthDate),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime monthDate) {
    final monthName = 'Tháng ${monthDate.month} ${monthDate.year}';
    final daysInMonth =
        DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final firstWeekday =
        DateTime(monthDate.year, monthDate.month, 1).weekday % 7;

    final weekDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              monthName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Weekday header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays
              .map(
                (day) => SizedBox(
                  width: 38,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - firstWeekday + 1;
            final cellDate =
                DateTime(monthDate.year, monthDate.month, dayNumber);

            bool isStart = _selectedDateRange != null &&
                DateUtils.isSameDay(_selectedDateRange!.start, cellDate);
            bool isEnd = _selectedDateRange != null &&
                DateUtils.isSameDay(_selectedDateRange!.end, cellDate);
            bool isInRange = _selectedDateRange != null &&
                cellDate.isAfter(_selectedDateRange!.start) &&
                cellDate.isBefore(_selectedDateRange!.end);

            final isToday = DateUtils.isSameDay(DateTime.now(), cellDate);

            return GestureDetector(
              key: isStart ? _selectedDateKey : null,
              onTap: () => _onDateCellTapped(cellDate),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: (isStart || isEnd)
                      ? const LinearGradient(
                          colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                        )
                      : null,
                  color: (isStart || isEnd)
                      ? null
                      : (isInRange
                          ? AppTheme.primary.withOpacity(0.12)
                          : Colors.transparent),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular((isStart || isEnd) ? 30 : 8),
                  boxShadow: (isStart || isEnd)
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: (isStart || isEnd || isToday)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isStart || isEnd
                              ? Colors.white
                              : (isInRange
                                  ? AppTheme.primary
                                  : (isToday ? AppTheme.primary : AppTheme.darkText)),
                        ),
                      ),
                      if (isToday && !isStart && !isEnd)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // STEP 3: Companions & Privacy Level — Premium Modern Cards
  Widget _buildStep3Companions() {
    final privacyOptions = [
      {'title': 'Riêng tư', 'desc': 'Chỉ mình bạn có thể xem hành trình này', 'icon': Icons.lock_rounded},
      {'title': 'Thành viên', 'desc': 'Chỉ bạn và những người được mời tham gia', 'icon': Icons.group_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
            ).createShader(bounds),
            child: const Text(
              'Bạn đồng hành & Quyền xem',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Card 1: Companion Card
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
                        color: AppTheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Thêm người đi cùng',
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
                  'Thêm bạn đồng hành để hệ thống tự động gửi thư mời tham gia với phân quyền tương ứng.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Invited list chips with role badge & Dismissible
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
                                backgroundColor: AppTheme.primary,
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
                                  color: isEditor
                                      ? AppTheme.primary.withOpacity(0.1)
                                      : Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isEditor ? 'Chỉnh sửa' : 'Chỉ xem',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEditor ? AppTheme.primary : Colors.amber[800],
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

                // + Mời button with gradient
                GestureDetector(
                  onTap: _showAddCompanionDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.25),
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
                          'Thêm Email người nhận',
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

          // Card 2: Privacy Level Radio Selector Cards
          Text(
            'Mức độ riêng tư chuyến đi',
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
                      color: isSelected ? AppTheme.primary : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.08),
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
                          color: isSelected
                              ? AppTheme.primary.withOpacity(0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected ? AppTheme.primary : Colors.grey[500],
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
                                color: isSelected ? AppTheme.primary : AppTheme.darkText,
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
                            color: isSelected ? AppTheme.primary : Colors.grey[300]!,
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

  // STEP 4: Trip Preferences — Premium Animated Category Grid
  Widget _buildStep4Interests() {
    final categoriesListToDisplay =
        _dbCategories.isNotEmpty ? _dbCategories : _defaultCategoriesData;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
            ).createShader(bounds),
            child: const Text(
              'Sở thích chuyến đi',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lựa chọn các danh mục để CloudMood cá nhân hóa hành trình tốt nhất cho bạn.',
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
                  AppTheme.primary.withOpacity(0.08),
                  const Color(0xFFEFF6FF),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.primary.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.06),
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
                          color: AppTheme.primary,
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
                  activeColor: AppTheme.primary,
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
            'Chuyến đi này tập trung vào:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 14),

          // Categories Selection Grid
          if (_isLoadingCategories)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
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
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(30),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey[200]!),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.3),
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.darkText,
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

  // BOTTOM NAVIGATION BAR — Premium Gradient CTA
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
          top: BorderSide(
            color: Colors.grey[100]!,
            width: 1,
          ),
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
              gradient: _isSaving
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                    ),
              color: _isSaving ? Colors.grey[300] : null,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
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
                                _currentStep == 4
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
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

          // Secondary Text Button ("Có thể sau" for Step 3)
          if (_currentStep == 3) ...[
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
          ? (cat['iconCode'] is int
              ? cat['iconCode']
              : int.tryParse(cat['iconCode'].toString()))
          : null;

      if (iconCode != null && iconCode > 0) {
        return Icon(
          IconData(iconCode, fontFamily: 'MaterialIcons'),
          size: 18,
          color: AppTheme.primary,
        );
      }

      final String name = (cat['name'] ?? '').toString().toLowerCase();
      if (cat['emoji'] != null &&
          cat['emoji'].toString().isNotEmpty &&
          cat['emoji'] != '📍') {
        return Text(cat['emoji'].toString(), style: const TextStyle(fontSize: 18));
      }

      if (name.contains('nhà hàng')) return const Icon(Icons.restaurant_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('khách sạn')) return const Icon(Icons.hotel_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('quán ăn')) return const Icon(Icons.fastfood_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('cà phê') || name.contains('cafe')) return const Icon(Icons.local_cafe_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('trung tâm thương mại') || name.contains('mua sắm')) return const Icon(Icons.shopping_bag_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('công viên') || name.contains('thiên nhiên')) return const Icon(Icons.park_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('bảo tàng') || name.contains('văn hóa')) return const Icon(Icons.museum_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('điểm tham quan') || name.contains('tham quan')) return const Icon(Icons.tour_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('trường học')) return const Icon(Icons.school_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('bar') || name.contains('đêm')) return const Icon(Icons.local_bar_rounded, size: 18, color: AppTheme.primary);
      if (name.contains('check-in') || name.contains('sống ảo')) return const Icon(Icons.camera_alt_rounded, size: 18, color: AppTheme.primary);
    }
    return const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.primary);
  }

  String _getStepTitleLabel(int step) {
    switch (step) {
      case 0:
        return 'Tên chuyến đi';
      case 1:
        return 'Điểm đến';
      case 2:
        return 'Ngày khởi hành';
      case 3:
        return 'Bạn đồng hành';
      case 4:
        return 'Sở thích';
      default:
        return '';
    }
  }

  Widget _buildQuickPresetChip(String label, int totalDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetEnd = today.add(Duration(days: totalDays - 1));

    final isSelected = _selectedDateRange != null &&
        DateUtils.isSameDay(_selectedDateRange!.start, today) &&
        DateUtils.isSameDay(_selectedDateRange!.end, targetEnd);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary.withOpacity(0.15),
      checkmarkColor: AppTheme.primary,
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.darkText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Colors.grey[200]!,
        ),
      ),
      onSelected: (bool selected) {
        setState(() {
          _selectedDateRange = DateTimeRange(start: today, end: targetEnd);
          _lastTappedDate = targetEnd;
          _days = totalDays;
        });
        _scrollToSelectedDate();
      },
    );
  }

  String _getPrimaryButtonText() {
    switch (_currentStep) {
      case 0:
      case 1:
      case 2:
        return 'Tiếp tục';
      case 3:
        return 'Mời bạn đồng hành';
      case 4:
        return 'Hoàn tất & Tạo lịch trình';
      default:
        return 'Tiếp tục';
    }
  }
}
