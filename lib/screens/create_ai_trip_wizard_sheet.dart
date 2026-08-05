import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import 'trip_overview_screen.dart';

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

class CreateAITripWizardSheet extends StatefulWidget {
  const CreateAITripWizardSheet({super.key});

  @override
  State<CreateAITripWizardSheet> createState() =>
      _CreateAITripWizardSheetState();
}

class _CreateAITripWizardSheetState extends State<CreateAITripWizardSheet> {
  static const Color _aiPurple = Color(0xFF8E2DE2);
  static const Color _aiPurpleDark = Color(0xFF4A00E0);

  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;

  bool _isCreating = false;

  // Step 0: Trip Title & Destination
  final _tripTitleController = TextEditingController();
  final _destinationSearchController = TextEditingController();
  String _selectedDestination = '';
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  Timer? _searchDebounce;
  bool _userEditedTitle = false;

  double _creationProgress = 0.0;
  int _activeStepIndex = 0;
  Timer? _progressTimer;

  final List<Map<String, String>> _aiLoadingSteps = [
    {
      'title': 'Đang tìm kiếm địa điểm phù hợp',
      'desc': 'Thu thập dữ liệu thực tế từ hệ thống CloudMood...',
    },
    {
      'title': 'Trợ lý AI đang phân tích',
      'desc': 'OpenAI GPT đọc hiểu yêu cầu và chọn lọc địa điểm...',
    },
    {
      'title': 'AI lên kế hoạch từng ngày',
      'desc': 'Sắp xếp lộ trình tối ưu, viết ghi chú cho mỗi điểm đến...',
    },
    {
      'title': 'Hoàn tất và khởi tạo lịch trình',
      'desc': 'Lưu lịch trình AI cá nhân hóa của bạn...',
    },
  ];

  void _startProgressTimer() {
    _creationProgress = 0.05;
    _activeStepIndex = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted || !_isCreating) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_creationProgress < 0.92) {
          _creationProgress += 0.035;
          if (_creationProgress >= 0.78) {
            _activeStepIndex = 3;
          } else if (_creationProgress >= 0.52) {
            _activeStepIndex = 2;
          } else if (_creationProgress >= 0.25) {
            _activeStepIndex = 1;
          } else {
            _activeStepIndex = 0;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _tripTitleController.dispose();
    _destinationSearchController.dispose();
    _searchDebounce?.cancel();
    _calendarScrollController.dispose();
    _companionInputController.dispose();
    _customBudgetController.dispose();
    _customRequestController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _selectDestination(String destName) {
    setState(() {
      _selectedDestination = destName;
      if (!_userEditedTitle || _tripTitleController.text.trim().isEmpty) {
        _tripTitleController.text = 'Chuyến đi $destName AI';
      }
    });
  }

  final List<Map<String, String>> _popularDestinations = [
    {
      'name': 'Cần Thơ',
      'flag': '🇻🇳',
      'desc': 'Thủ phủ miền Tây - Chợ nổi Cái Răng',
    },
    {
      'name': 'Đà Nẵng',
      'flag': '🇻🇳',
      'desc': 'Thành phố đáng sống - Cầu Rồng & Biển Mỹ Khê',
    },
    {
      'name': 'Hà Nội',
      'flag': '🇻🇳',
      'desc': 'Thủ đô ngàn năm văn hiến - Phố cổ & Hồ Gươm',
    },
    {
      'name': 'TP. Hồ Chí Minh',
      'flag': '🇻🇳',
      'desc': 'Thành phố sôi động - Sài Gòn rực rỡ',
    },
    {
      'name': 'Đà Lạt',
      'flag': '🇻🇳',
      'desc': 'Thành phố ngàn hoa - Khí hậu ôn hòa',
    },
    {
      'name': 'Phú Quốc',
      'flag': '🇻🇳',
      'desc': 'Đảo ngọc thiên đường - Bãi biển tuyệt đẹp',
    },
    {
      'name': 'Hội An',
      'flag': '🇻🇳',
      'desc': 'Phố cổ đèn lồng - Di sản thế giới',
    },
    {
      'name': 'Nha Trang',
      'flag': '🇻🇳',
      'desc': 'Vịnh biển xanh mát - VinWonders',
    },
    {
      'name': 'Sa Pa',
      'flag': '🇻🇳',
      'desc': 'Thành phố trong sương - Đỉnh Fansipan',
    },
    {
      'name': 'Ninh Bình',
      'flag': '🇻🇳',
      'desc': 'Tràng An - Ha Long trên cạn',
    },
  ];

  // Step 1: Date selection (Max 7 Days Limit)
  DateTimeRange? _selectedDateRange;
  DateTime? _lastTappedDate;
  bool _isSelectingEndDate = false;
  int _days = 3;
  late final ScrollController _calendarScrollController = ScrollController();
  final GlobalKey _selectedDateKey = GlobalKey();
  final GlobalKey _currentMonthKey = GlobalKey();

  // Step 2: Dynamic DB Categories (Sở thích / Chủ đề chuyến đi)
  List<Map<String, dynamic>> _dbCategories = [];
  bool _isLoadingCategories = false;
  final List<String> _selectedCategories =
      []; // Default empty = ALL categories!
  bool _includeTopAttractions = true;

  final List<Map<String, dynamic>> _defaultCategoriesData = [
    {'name': 'Nhà hàng', 'iconCode': Icons.restaurant_rounded.codePoint},
    {'name': 'Khách sạn', 'iconCode': Icons.hotel_rounded.codePoint},
    {'name': 'Quán ăn', 'iconCode': Icons.fastfood_rounded.codePoint},
    {'name': 'Cà phê', 'iconCode': Icons.local_cafe_rounded.codePoint},
    {
      'name': 'Trung tâm thương mại',
      'iconCode': Icons.shopping_bag_rounded.codePoint,
    },
    {'name': 'Công viên', 'iconCode': Icons.park_rounded.codePoint},
    {'name': 'Bảo tàng', 'iconCode': Icons.museum_rounded.codePoint},
    {'name': 'Check-in', 'iconCode': Icons.camera_alt_rounded.codePoint},
  ];

  // Step 3: Pace (Nhịp độ chuyến đi)
  String _selectedPace = 'Vừa phải (4-5 điểm/ngày)';
  final List<Map<String, String>> _paces = [
    {'name': 'Thong thả (3-4 điểm/ngày)', 'desc': 'Thư giãn, không vội vã'},
    {
      'name': 'Vừa phải (4-5 điểm/ngày)',
      'desc': 'Cân bằng giữa trải nghiệm và nghỉ ngơi',
    },
    {'name': 'Dày đặc (6 điểm/ngày)', 'desc': 'Khám phá tối đa các điểm đến'},
  ];

  // Step 4: Companions & Privacy (Email invites + Role)
  final List<InvitedCompanion> _invitedCompanionsList = [];
  final TextEditingController _companionInputController =
      TextEditingController();
  String _privacyLevel = 'Riêng tư'; // 'Riêng tư', 'Thành viên'

  // Step 5: Budget & Currency (Single value for total trip)
  bool _useCustomBudget = false;
  String _selectedBudgetLevel = 'Vừa phải'; // Tiết kiệm, Vừa phải, Sang trọng
  final TextEditingController _customBudgetController = TextEditingController(
    text: '7,000,000',
  );
  String _selectedCurrency = 'VND';
  final List<String> _currencies = ['VND', 'USD', 'EUR', 'JPY', 'KRW', 'THB'];

  // Custom Request for Gemini AI (optional free text from user)
  final TextEditingController _customRequestController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDateRange = DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 2)),
    );
    _days = 3;

    _loadCategoriesFromDB();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  Future<void> _loadCategoriesFromDB() async {
    setState(() => _isLoadingCategories = true);
    try {
      final cats = await DatabaseService().getCategories();
      if (cats.isNotEmpty) {
        setState(() {
          _dbCategories = cats;
          _isLoadingCategories = false;
        });
      } else {
        setState(() => _isLoadingCategories = false);
      }
    } catch (e) {
      debugPrint('Error fetching categories for wizard: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoadingSearch = false;
      });
      return;
    }

    setState(() => _isLoadingSearch = true);

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('${query.trim()}, Vietnam')}&format=json&addressdetails=1&limit=10',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'CloudMoodApp/1.0'},
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final filteredAreas = data.where((item) {
            final placeClass = (item['class'] ?? '').toString().toLowerCase();
            final type = (item['type'] ?? '').toString().toLowerCase();

            if (placeClass == 'amenity' ||
                placeClass == 'shop' ||
                placeClass == 'tourism' ||
                placeClass == 'building' ||
                placeClass == 'leisure' ||
                placeClass == 'craft' ||
                type == 'restaurant' ||
                type == 'hotel' ||
                type == 'cafe') {
              return false;
            }
            return true;
          }).toList();

          if (mounted) {
            setState(() {
              _searchResults = filteredAreas.isNotEmpty ? filteredAreas : data;
              _isLoadingSearch = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingSearch = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingSearch = false);
        }
      }
    });
  }

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

  void _onDateCellTapped(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cleanDate = DateTime(date.year, date.month, date.day);

    if (cleanDate.isBefore(today)) return;

    setState(() {
      if (!_isSelectingEndDate ||
          _selectedDateRange == null ||
          cleanDate.isBefore(_selectedDateRange!.start)) {
        _selectedDateRange = DateTimeRange(start: cleanDate, end: cleanDate);
        _lastTappedDate = cleanDate;
        _days = 1;
        _isSelectingEndDate = true;
      } else {
        var start = _selectedDateRange!.start;
        int daysBetween = cleanDate.difference(start).inDays + 1;
        var end = cleanDate;
        if (daysBetween > 7) {
          end = start.add(const Duration(days: 6));
          daysBetween = 7;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lịch trình AI tối đa 7 ngày!'),
              behavior: SnackBarBehavior.fixed,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _selectedDateRange = DateTimeRange(start: start, end: end);
        _days = daysBetween;
        _lastTappedDate = cleanDate;
        _isSelectingEndDate = false;
      }
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final dest = _destinationSearchController.text.trim().isNotEmpty
          ? _destinationSearchController.text.trim()
          : _selectedDestination;
      if (dest.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn hoặc nhập điểm đến cho chuyến đi!'),
            backgroundColor: AppTheme.amber,
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createAIItinerary();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createAIItinerary() async {
    final user = AuthService().currentUser.value;
    final int currentUserId = user?.id ?? 1;

    setState(() => _isCreating = true);
    _startProgressTimer();

    // Calculate budget number for whole trip
    int budgetInVND = 7000000;
    if (_useCustomBudget && _customBudgetController.text.trim().isNotEmpty) {
      final raw = _customBudgetController.text
          .replaceAll(',', '')
          .replaceAll('.', '')
          .trim();
      budgetInVND = int.tryParse(raw) ?? 7000000;
    } else {
      final bLower = _selectedBudgetLevel.toLowerCase();
      if (bLower.contains('tiết kiệm') || bLower.contains('tiet kiem')) {
        budgetInVND = 3000000;
      } else if (bLower.contains('sang trọng') ||
          bLower.contains('sang trong') ||
          bLower.contains('sang')) {
        budgetInVND = 15000000;
      } else {
        budgetInVND = 7000000;
      }
    }

    final String finalDestination =
        _destinationSearchController.text.trim().isNotEmpty
        ? _destinationSearchController.text.trim()
        : (_selectedDestination.isNotEmpty ? _selectedDestination : 'Cần Thơ');

    final String title = _tripTitleController.text.trim().isNotEmpty
        ? _tripTitleController.text.trim()
        : 'Du lịch $finalDestination cùng AI';

    final startDate = _selectedDateRange?.start ?? DateTime.now();

    Map<String, dynamic>? result;
    int itineraryId = 0;

    try {
      // ── STEP A: Create the empty itinerary shell in DB ──────────────────────
      result = await DatabaseService().createUserItinerary(
        userId: currentUserId,
        title: title,
        destination: finalDestination,
        startDate: startDate,
        days: _days,
        budget: budgetInVND,
        companion: _privacyLevel,
        pace: 'Vừa phải',
        categories: _selectedCategories.isNotEmpty
            ? _selectedCategories
            : ['Tất cả'],
        amenities: [],
        isAi: true,
      );

      if (result == null || result['id'] == null) {
        if (mounted) {
          setState(() => _isCreating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo hành trình thất bại. Vui lòng thử lại.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      itineraryId = (result['id'] is int)
          ? result['id']
          : int.tryParse(result['id'].toString()) ?? 0;

      if (itineraryId <= 0) {
        if (mounted) {
          setState(() => _isCreating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lỗi khởi tạo hành trình. Vui lòng thử lại.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Save privacy prefs & invite companions
      final prefs = await SharedPreferences.getInstance();
      String privacyVal = 'private';
      if (_privacyLevel == 'Thành viên' || _privacyLevel == 'MEMBERS') {
        privacyVal = 'members';
      }
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

      // ── STEP B: Call Gemini AI (Hybrid RAG + AI Agent) ─────────────────────
      if (mounted) {
        setState(() {
          _creationProgress = math.max(_creationProgress, 0.35);
          _activeStepIndex = math.max(_activeStepIndex, 1);
        });
      }

      final String customReq = _customRequestController.text.trim();

      final aiPlan = await DatabaseService().generateAIItinerary(
        destination: finalDestination,
        days: _days,
        pace: 'Vừa phải',
        companion: _privacyLevel,
        budget: _selectedBudgetLevel,
        categories: _selectedCategories,
        startDate: startDate,
        customRequest: customReq.isNotEmpty ? customReq : null,
      );

      if (mounted) {
        setState(() {
          _creationProgress = math.max(_creationProgress, 0.75);
          _activeStepIndex = math.max(_activeStepIndex, 2);
        });
      }

      // ── STEP C: Save AI itinerary details into DB ──────────────────────────
      int totalAdded = 0;
      final List<dynamic> aiDays = aiPlan['days'] ?? [];
      final List<Map<String, dynamic>> bulkDetails = [];

      for (final dayData in aiDays) {
        final int dayNumber = (dayData['dayNumber'] ?? 1) as int;
        final String dayTitle = (dayData['dayTitle'] ?? '').toString();
        final List<dynamic> places = dayData['places'] ?? [];

        for (int pi = 0; pi < places.length; pi++) {
          final placeEntry = places[pi];
          final int placeId = (placeEntry['placeId'] is int)
              ? placeEntry['placeId']
              : int.tryParse(placeEntry['placeId'].toString()) ?? 0;
          final String note = (placeEntry['note'] ?? '').toString();

          if (placeId <= 0) continue;

          final timeSlot = _calculatePlaceTimeSlot(pi, places.length);
          final String startTime =
              (placeEntry['startTime'] != null &&
                  placeEntry['startTime'].toString().contains(':'))
              ? placeEntry['startTime'].toString()
              : (timeSlot['startTime'] ?? '07:00');
          final String endTime =
              (placeEntry['endTime'] != null &&
                  placeEntry['endTime'].toString().contains(':'))
              ? placeEntry['endTime'].toString()
              : (timeSlot['endTime'] ?? '08:30');

          bulkDetails.add({
            'placeId': placeId,
            'day': dayNumber,
            'sortOrder': pi,
            'noteText': note.isNotEmpty ? note : dayTitle,
            'startTime': startTime,
            'endTime': endTime,
          });
        }
      }

      if (bulkDetails.isNotEmpty) {
        final ok = await DatabaseService().addBulkPlacesToItinerary(
          itineraryId: itineraryId,
          details: bulkDetails,
        );
        if (ok) totalAdded = bulkDetails.length;
      }

      if (totalAdded == 0) {
        await _autoPopulatePlacesForAIItinerary(
          itineraryId,
          finalDestination,
          _days,
          'Vừa phải',
          _selectedCategories,
          true,
          selectedBudgetLevel: _selectedBudgetLevel,
          budgetInVND: budgetInVND,
        );
      }

      if (mounted) {
        setState(() {
          _creationProgress = 1.0;
          _activeStepIndex = 3;
        });
        await Future.delayed(const Duration(milliseconds: 400));

        final updatedResult =
            await DatabaseService().fetchItineraryById(itineraryId) ?? result;

        _progressTimer?.cancel();

        if (mounted) {
          Navigator.of(
            context,
          ).pop(); // Close wizard sheet cleanly while overlay covers UI

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TripOverviewScreen(
                itinerary: updatedResult,
                initialTabIndex: 1, // Directly open "Hành trình" tab
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OpenAI GPT đã tạo lịch trình $_days ngày cho bạn!',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF8E2DE2),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AI Generation error: $e');
      // Fallback: Populate itinerary with RAG places if AI call fails
      if (itineraryId > 0) {
        try {
          await _autoPopulatePlacesForAIItinerary(
            itineraryId,
            finalDestination,
            _days,
            'Vừa phải',
            _selectedCategories,
            true,
            selectedBudgetLevel: _selectedBudgetLevel,
            budgetInVND: budgetInVND,
          );

          if (mounted) {
            setState(() {
              _creationProgress = 1.0;
              _activeStepIndex = 3;
            });
            await Future.delayed(const Duration(milliseconds: 400));

            final updatedResult =
                await DatabaseService().fetchItineraryById(itineraryId) ??
                result;

            _progressTimer?.cancel();

            if (mounted) {
              Navigator.of(context).pop();

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TripOverviewScreen(
                    itinerary: updatedResult!,
                    initialTabIndex: 1,
                  ),
                ),
              );
              return;
            }
          }
        } catch (fallbackErr) {
          debugPrint('Fallback auto-populate error: $fallbackErr');
        }
      }

      if (mounted) {
        _progressTimer?.cancel();
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _autoPopulatePlacesForAIItinerary(
    int itineraryId,
    String destination,
    int days,
    String paceStr,
    List<String> selectedCategories,
    bool includeTopAttractions, {
    String selectedBudgetLevel = 'Vừa phải',
    int budgetInVND = 7000000,
  }) async {
    try {
      final String cleanDestination = destination
          .replaceAll(
            RegExp(r'(Chuyến đi|AI|Lịch trình)', caseSensitive: false),
            '',
          )
          .trim();
      final String searchDest = cleanDestination.isNotEmpty
          ? cleanDestination
          : destination;

      List<dynamic> places = await DatabaseService().searchPlaces(
        destination: searchDest,
        minRating: includeTopAttractions ? 4.0 : null,
      );

      if (places.isEmpty) {
        places = await DatabaseService().searchPlaces(destination: searchDest);
      }
      if (places.isEmpty) {
        places = await DatabaseService().fetchPlacesByDestination(searchDest);
      }
      if (places.isEmpty) {
        places = await DatabaseService().fetchPlaces();
      }

      if (places.isEmpty) return;

      // Filter by selected categories if user made specific selections (ignore 'Tất cả')
      if (selectedCategories.isNotEmpty &&
          !selectedCategories.contains('Tất cả')) {
        final filtered = places.where((p) {
          final catObj = p['category'];
          final String catName = (catObj != null && catObj['name'] != null)
              ? catObj['name'].toString().toLowerCase()
              : (p['categoryName'] ?? '').toString().toLowerCase();

          final String placeName = (p['name'] ?? '').toString().toLowerCase();
          final String description = (p['description'] ?? '')
              .toString()
              .toLowerCase();

          return selectedCategories.any((selectedCat) {
            final s = selectedCat.toLowerCase();
            final cleanS = s.split('&')[0].trim().toLowerCase();
            return catName.contains(cleanS) ||
                cleanS.contains(catName) ||
                placeName.contains(cleanS) ||
                description.contains(cleanS);
          });
        }).toList();

        if (filtered.isNotEmpty) {
          places = filtered;
        }
      }

      // Enforce Top Rated Filter (⭐ 4.0+) if toggle is enabled
      if (includeTopAttractions) {
        final topRated = places.where((p) {
          final double r = (p['rating'] != null)
              ? (double.tryParse(p['rating'].toString()) ?? 0.0)
              : 0.0;
          return r >= 4.0;
        }).toList();

        if (topRated.isNotEmpty) {
          places = topRated;
        }

        // Sort descending by rating
        places.sort((a, b) {
          final double rA = (a['rating'] != null)
              ? (double.tryParse(a['rating'].toString()) ?? 0.0)
              : 0.0;
          final double rB = (b['rating'] != null)
              ? (double.tryParse(b['rating'].toString()) ?? 0.0)
              : 0.0;
          return rB.compareTo(rA);
        });
      }

      // Filter and prioritize places by priceLevel in DB based on user selected budget
      places = _filterPlacesByBudgetLevel(
        places: places,
        selectedBudgetLevel: selectedBudgetLevel,
        totalBudgetVND: budgetInVND,
      );

      int placesPerDay = 9;

      final int totalNeeded = days * placesPerDay;

      // If filtered places count is less than needed total, fetch all places for destination to supplement!
      if (places.length < totalNeeded) {
        final allDestPlaces = await DatabaseService().fetchPlacesByDestination(
          searchDest,
        );
        final Set<dynamic> existingIds = places.map((p) => p['id']).toSet();
        for (final p in allDestPlaces) {
          if (places.length >= totalNeeded) break;
          if (!existingIds.contains(p['id'])) {
            existingIds.add(p['id']);
            places.add(p);
          }
        }
      }

      // If still less than totalNeeded, supplement with all system places
      if (places.length < totalNeeded) {
        final allSystemPlaces = await DatabaseService().fetchPlaces();
        final Set<dynamic> existingIds = places.map((p) => p['id']).toSet();
        for (final p in allSystemPlaces) {
          if (places.length >= totalNeeded) break;
          if (!existingIds.contains(p['id'])) {
            existingIds.add(p['id']);
            places.add(p);
          }
        }
      }

      // If STILL less than totalNeeded, cycle/repeat candidates so every day has enough places!
      if (places.isNotEmpty && places.length < totalNeeded) {
        final initialLen = places.length;
        int cycleIdx = 0;
        while (places.length < totalNeeded) {
          places.add(places[cycleIdx % initialLen]);
          cycleIdx++;
        }
      }

      final DateTime tripStartDate =
          _selectedDateRange?.start ?? DateTime.now();

      // Optimize AI Place Assignment using Geographic Clustering & Nearest-Neighbor Pathing
      final Map<int, List<dynamic>> optimizedPlan =
          _optimizePlacesBySpatialClustering(
            candidatePlaces: places,
            totalDays: days,
            placesPerDay: placesPerDay,
            startDate: tripStartDate,
          );

      final List<Map<String, dynamic>> bulkDetails = [];

      for (int day = 1; day <= days; day++) {
        final dayPlaces = optimizedPlan[day] ?? [];
        int placeIndexForDay = 0;
        final Set<int> dayAddedPlaceIds =
            {}; // Scope dedup to the current day only!

        for (int i = 0; i < dayPlaces.length; i++) {
          final place = dayPlaces[i];
          final int placeId = (place['id'] is int)
              ? place['id']
              : int.tryParse(place['id'].toString()) ?? 0;

          if (placeId > 0 && !dayAddedPlaceIds.contains(placeId)) {
            dayAddedPlaceIds.add(placeId);

            final timeSlot = _calculatePlaceTimeSlot(placeIndexForDay, 9);
            final inspiringNote = _generateInspiringAINote(
              place: place,
              day: day,
              placeIndex: placeIndexForDay,
              totalPlacesForDay: dayPlaces.length,
            );

            bulkDetails.add({
              'placeId': placeId,
              'day': day,
              'sortOrder': placeIndexForDay + 1,
              'noteText': inspiringNote,
              'startTime': timeSlot['startTime'],
              'endTime': timeSlot['endTime'],
            });
            placeIndexForDay++;
          }
        }
      }

      if (bulkDetails.isNotEmpty) {
        await DatabaseService().addBulkPlacesToItinerary(
          itineraryId: itineraryId,
          details: bulkDetails,
        );
      }
    } catch (e) {
      debugPrint('Error auto populating AI places: $e');
    }
  }

  /// Filter & Sort Places by exact priceLevel values in Database: (FREE, $, MODERATE, $$-$$$, $$$$)
  List<dynamic> _filterPlacesByBudgetLevel({
    required List<dynamic> places,
    required String selectedBudgetLevel,
    required int totalBudgetVND,
  }) {
    if (places.isEmpty) return places;

    final String b = selectedBudgetLevel.toLowerCase();

    if (b.contains('tiết kiệm') || totalBudgetVND <= 3000000) {
      // Tiết kiệm: Lọc bỏ $$$$ và $$-$$$. Giữ lại FREE, $ và MODERATE.
      final filtered = places.where((p) {
        final String rawPl = (p['priceLevel'] ?? p['price_level'] ?? '')
            .toString()
            .toUpperCase()
            .trim();
        if (rawPl == '\$\$\$\$' ||
            rawPl.contains('\$\$\$') ||
            rawPl.contains('\$\$-\$\$\$')) {
          return false;
        }
        return true;
      }).toList();

      if (filtered.isNotEmpty) {
        // Ưu tiên đưa FREE và $ lên hàng đầu
        filtered.sort((a, b) {
          final String plA = (a['priceLevel'] ?? a['price_level'] ?? '')
              .toString()
              .toUpperCase()
              .trim();
          final String plB = (b['priceLevel'] ?? b['price_level'] ?? '')
              .toString()
              .toUpperCase()
              .trim();
          final int scoreA = (plA == 'FREE' || plA == '\$')
              ? 0
              : (plA == 'MODERATE' ? 1 : 2);
          final int scoreB = (plB == 'FREE' || plB == '\$')
              ? 0
              : (plB == 'MODERATE' ? 1 : 2);
          return scoreA.compareTo(scoreB);
        });
        return filtered;
      }
    } else if (b.contains('vừa phải') ||
        (totalBudgetVND > 3000000 && totalBudgetVND <= 10000000)) {
      // Vừa phải: Loại bỏ mức xa xỉ $$$$ (vì $$$$ rất ít địa điểm). Giữ lại MODERATE, $$-$$$, $, FREE.
      final filtered = places.where((p) {
        final String rawPl = (p['priceLevel'] ?? p['price_level'] ?? '')
            .toString()
            .toUpperCase()
            .trim();
        if (rawPl == '\$\$\$\$') return false;
        return true;
      }).toList();

      if (filtered.isNotEmpty) {
        // Sắp xếp ưu tiên MODERATE và $$-$$$ lên trước
        filtered.sort((a, b) {
          final String plA = (a['priceLevel'] ?? a['price_level'] ?? '')
              .toString()
              .toUpperCase()
              .trim();
          final String plB = (b['priceLevel'] ?? b['price_level'] ?? '')
              .toString()
              .toUpperCase()
              .trim();
          final int scoreA = (plA == 'MODERATE' || plA.contains('\$\$-\$\$\$'))
              ? 0
              : 1;
          final int scoreB = (plB == 'MODERATE' || plB.contains('\$\$-\$\$\$'))
              ? 0
              : 1;
          return scoreA.compareTo(scoreB);
        });
        return filtered;
      }
    } else if (b.contains('sang trọng') || totalBudgetVND > 10000000) {
      // Sang trọng: Đưa các địa điểm xa xỉ $$$$ và $$-$$$ lên đầu.
      // Nếu số lượng $$$$ ít, tự động bổ sung $$-$$$ và MODERATE để không bao giờ bị thiếu địa điểm!
      final List<dynamic> sortedPlaces = List.from(places);
      sortedPlaces.sort((a, b) {
        final String plA = (a['priceLevel'] ?? a['price_level'] ?? '')
            .toString()
            .toUpperCase()
            .trim();
        final String plB = (b['priceLevel'] ?? b['price_level'] ?? '')
            .toString()
            .toUpperCase()
            .trim();

        int scoreA = 3;
        if (plA == '\$\$\$\$')
          scoreA = 0;
        else if (plA.contains('\$\$-\$\$\$'))
          scoreA = 1;
        else if (plA == 'MODERATE')
          scoreA = 2;

        int scoreB = 3;
        if (plB == '\$\$\$\$')
          scoreB = 0;
        else if (plB.contains('\$\$-\$\$\$'))
          scoreB = 1;
        else if (plB == 'MODERATE')
          scoreB = 2;

        return scoreA.compareTo(scoreB);
      });
      return sortedPlaces;
    }

    return places;
  }

  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  double _getPlaceLat(dynamic p) {
    if (p is Map) {
      if (p['latitude'] != null)
        return double.tryParse(p['latitude'].toString()) ?? 0.0;
      if (p['lat'] != null) return double.tryParse(p['lat'].toString()) ?? 0.0;
    }
    return 0.0;
  }

  double _getPlaceLng(dynamic p) {
    if (p is Map) {
      if (p['longitude'] != null)
        return double.tryParse(p['longitude'].toString()) ?? 0.0;
      if (p['lng'] != null) return double.tryParse(p['lng'].toString()) ?? 0.0;
    }
    return 0.0;
  }

  /// Optimize AI Place Assignment across Days using K-Means Spatial Clustering & Nearest-Neighbor Pathing
  Map<int, List<dynamic>> _optimizePlacesBySpatialClustering({
    required List<dynamic> candidatePlaces,
    required int totalDays,
    required int placesPerDay,
    required DateTime startDate,
  }) {
    final Map<int, List<dynamic>> dayPlan = {};
    if (candidatePlaces.isEmpty) return dayPlan;

    // Filter out places that are closed on ALL days of the trip
    final List<dynamic> openPlaces = candidatePlaces.where((place) {
      final hours =
          place['regularOpeningHours'] ??
          place['openingHours'] ??
          place['opening_hours'];
      if (hours == null) return true;
      for (int d = 0; d < totalDays; d++) {
        final dayDate = startDate.add(Duration(days: d));
        if (TimeUtils.isPlaceOpenOnDate(hours, dayDate)) return true;
      }
      return false;
    }).toList();

    final List<dynamic> poolSource = openPlaces.isNotEmpty
        ? openPlaces
        : candidatePlaces;
    final int totalNeeded = totalDays * placesPerDay;

    // Shuffle pool to generate unique, varied, and diverse itineraries on each AI generation!
    final List<dynamic> shuffledPool = List.from(poolSource);
    shuffledPool.shuffle();

    final List<dynamic> selectedPool = shuffledPool.take(totalNeeded).toList();

    // Step 1: Initialize Centroids for Spatial Clustering
    List<Map<String, double>> centroids = [];
    final int stepSize = (selectedPool.length / totalDays).floor().clamp(
      1,
      selectedPool.length,
    );
    for (int d = 0; d < totalDays; d++) {
      final idx = (d * stepSize) % selectedPool.length;
      centroids.add({
        'lat': _getPlaceLat(selectedPool[idx]),
        'lng': _getPlaceLng(selectedPool[idx]),
      });
    }

    Map<int, List<dynamic>> clusters = {};

    // 5 Iterations of K-Means Clustering to group nearby places into the same day
    for (int iter = 0; iter < 5; iter++) {
      for (int d = 1; d <= totalDays; d++) clusters[d] = [];

      for (final place in selectedPool) {
        final pLat = _getPlaceLat(place);
        final pLng = _getPlaceLng(place);
        final hours =
            place['regularOpeningHours'] ??
            place['openingHours'] ??
            place['opening_hours'];

        int bestDay = 1;
        double minDistance = double.infinity;

        for (int d = 0; d < totalDays; d++) {
          final dayDate = startDate.add(Duration(days: d));
          final bool isOpenOnDay = TimeUtils.isPlaceOpenOnDate(hours, dayDate);

          double dist = _calculateHaversineDistance(
            pLat,
            pLng,
            centroids[d]['lat']!,
            centroids[d]['lng']!,
          );

          // Evenly distribute places across days
          if (!isOpenOnDay) {
            dist += 5.0;
          }

          if (dist < minDistance &&
              (clusters[d + 1]!.length < placesPerDay + 1)) {
            minDistance = dist;
            bestDay = d + 1;
          }
        }
        clusters[bestDay]!.add(place);
      }

      for (int d = 0; d < totalDays; d++) {
        final dayList = clusters[d + 1]!;
        if (dayList.isNotEmpty) {
          double sumLat = 0.0;
          double sumLng = 0.0;
          int validCount = 0;
          for (final p in dayList) {
            final lat = _getPlaceLat(p);
            final lng = _getPlaceLng(p);
            if (lat != 0.0 && lng != 0.0) {
              sumLat += lat;
              sumLng += lng;
              validCount++;
            }
          }
          if (validCount > 0) {
            centroids[d] = {
              'lat': sumLat / validCount,
              'lng': sumLng / validCount,
            };
          }
        }
      }
    }

    // Step 2: Inter-Day Swap Optimization (Eliminate Far-Away Outliers Across Days)
    for (int swapIter = 0; swapIter < 5; swapIter++) {
      bool swappedAny = false;

      final List<Map<String, double>> currentCentroids = List.generate(
        totalDays,
        (d) {
          final dayList = clusters[d + 1] ?? [];
          double sumLat = 0.0, sumLng = 0.0;
          int count = 0;
          for (final p in dayList) {
            final lat = _getPlaceLat(p);
            final lng = _getPlaceLng(p);
            if (lat != 0.0 && lng != 0.0) {
              sumLat += lat;
              sumLng += lng;
              count++;
            }
          }
          return {
            'lat': count > 0 ? sumLat / count : 0.0,
            'lng': count > 0 ? sumLng / count : 0.0,
          };
        },
      );

      for (int d1 = 1; d1 <= totalDays; d1++) {
        for (int d2 = d1 + 1; d2 <= totalDays; d2++) {
          final list1 = clusters[d1]!;
          final list2 = clusters[d2]!;
          final c1 = currentCentroids[d1 - 1];
          final c2 = currentCentroids[d2 - 1];
          if (c1['lat'] == 0.0 || c2['lat'] == 0.0) continue;

          final dayDate1 = startDate.add(Duration(days: d1 - 1));
          final dayDate2 = startDate.add(Duration(days: d2 - 1));

          for (int i = 0; i < list1.length; i++) {
            for (int j = 0; j < list2.length; j++) {
              final p1 = list1[i];
              final p2 = list2[j];

              final hours1 =
                  p1['regularOpeningHours'] ??
                  p1['openingHours'] ??
                  p1['opening_hours'];
              final hours2 =
                  p2['regularOpeningHours'] ??
                  p2['openingHours'] ??
                  p2['opening_hours'];

              if (!TimeUtils.isPlaceOpenOnDate(hours1, dayDate2)) continue;
              if (!TimeUtils.isPlaceOpenOnDate(hours2, dayDate1)) continue;

              final p1Lat = _getPlaceLat(p1);
              final p1Lng = _getPlaceLng(p1);
              final p2Lat = _getPlaceLat(p2);
              final p2Lng = _getPlaceLng(p2);

              final currentCost =
                  _calculateHaversineDistance(
                    p1Lat,
                    p1Lng,
                    c1['lat']!,
                    c1['lng']!,
                  ) +
                  _calculateHaversineDistance(
                    p2Lat,
                    p2Lng,
                    c2['lat']!,
                    c2['lng']!,
                  );

              final swappedCost =
                  _calculateHaversineDistance(
                    p1Lat,
                    p1Lng,
                    c2['lat']!,
                    c2['lng']!,
                  ) +
                  _calculateHaversineDistance(
                    p2Lat,
                    p2Lng,
                    c1['lat']!,
                    c1['lng']!,
                  );

              if (swappedCost < currentCost - 1.5) {
                list1[i] = p2;
                list2[j] = p1;
                swappedAny = true;
                break;
              }
            }
            if (swappedAny) break;
          }
        }
      }
      if (!swappedAny) break;
    }

    // Step 3: Sort places within each day using Greedy Nearest Neighbor Pathing
    for (int d = 1; d <= totalDays; d++) {
      final List<dynamic> dayPlaces = List.from(clusters[d] ?? []);
      if (dayPlaces.length <= 1) {
        dayPlan[d] = dayPlaces;
        continue;
      }

      final List<dynamic> orderedDayPlaces = [];
      final Set<int> visitedIndices = {};

      int currentIdx = 0;
      orderedDayPlaces.add(dayPlaces[currentIdx]);
      visitedIndices.add(currentIdx);

      while (orderedDayPlaces.length < dayPlaces.length) {
        final currentPlace = dayPlaces[currentIdx];
        final cLat = _getPlaceLat(currentPlace);
        final cLng = _getPlaceLng(currentPlace);

        int nextIdx = -1;
        double minDistance = double.infinity;

        for (int i = 0; i < dayPlaces.length; i++) {
          if (visitedIndices.contains(i)) continue;
          final nLat = _getPlaceLat(dayPlaces[i]);
          final nLng = _getPlaceLng(dayPlaces[i]);
          final dist = _calculateHaversineDistance(cLat, cLng, nLat, nLng);

          if (dist < minDistance) {
            minDistance = dist;
            nextIdx = i;
          }
        }

        if (nextIdx != -1) {
          orderedDayPlaces.add(dayPlaces[nextIdx]);
          visitedIndices.add(nextIdx);
          currentIdx = nextIdx;
        } else {
          break;
        }
      }

      dayPlan[d] = orderedDayPlaces;
    }

    return dayPlan;
  }

  Map<String, String> _calculatePlaceTimeSlot(
    int placeIndex,
    int totalPlacesForDay,
  ) {
    final slots = [
      {'startTime': '07:00', 'endTime': '08:30'}, // Slot 0: Ăn sáng / Coffee
      {'startTime': '08:30', 'endTime': '10:30'}, // Slot 1: Đi chơi 1
      {'startTime': '10:30', 'endTime': '12:30'}, // Slot 2: Đi chơi 2
      {'startTime': '12:30', 'endTime': '13:30'}, // Slot 3: Ăn trưa
      {
        'startTime': '13:30',
        'endTime': '15:00',
      }, // Slot 4: Đi chơi 3 / Check-in
      {'startTime': '15:00', 'endTime': '16:30'}, // Slot 5: Đi chơi 4
      {'startTime': '16:30', 'endTime': '18:00'}, // Slot 6: Đi chơi 5
      {'startTime': '18:00', 'endTime': '19:00'}, // Slot 7: Ăn tối
      {'startTime': '19:00', 'endTime': '22:00'}, // Slot 8: Đi chơi 6 / Coffee
    ];
    return slots[placeIndex % slots.length];
  }

  String _generateInspiringAINote({
    required Map<String, dynamic> place,
    required int day,
    required int placeIndex,
    required int totalPlacesForDay,
  }) {
    return '';
  }

  void _showAddCompanionDialog() {
    String dialogSelectedRole = 'EDITOR';
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
                      color: _aiPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: _aiPurple,
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
                          if (debounceTimer?.isActive ?? false)
                            debounceTimer!.cancel();
                          if (val.trim().isEmpty) {
                            setDialogState(() {
                              suggestions = [];
                              isSearching = false;
                            });
                            return;
                          }
                          debounceTimer = Timer(
                            const Duration(milliseconds: 300),
                            () async {
                              final results = await DatabaseService()
                                  .searchUsersByEmail(val.trim());
                              final alreadyInvited = _invitedCompanionsList
                                  .map((c) => c.email.toLowerCase())
                                  .toSet();
                              setDialogState(() {
                                suggestions = results
                                    .where(
                                      (u) => !alreadyInvited.contains(
                                        (u['email'] ?? '')
                                            .toString()
                                            .toLowerCase(),
                                      ),
                                    )
                                    .toList();
                                isSearching = false;
                              });
                            },
                          );
                        },
                      ),

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
                                  final String fullName =
                                      user['fullName'] ??
                                      'Người dùng CloudMood';
                                  final String email = user['email'] ?? '';
                                  final String? avatar = user['avatar'];

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 2,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _aiPurple.withOpacity(
                                        0.1,
                                      ),
                                      backgroundImage:
                                          (avatar != null && avatar.isNotEmpty)
                                          ? NetworkImage(avatar)
                                          : null,
                                      child: (avatar == null || avatar.isEmpty)
                                          ? const Icon(
                                              Icons.person,
                                              size: 18,
                                              color: _aiPurple,
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
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
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 16,
                              ),
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

                      // Role selector option 1: EDITOR
                      GestureDetector(
                        onTap: () {
                          setDialogState(() => dialogSelectedRole = 'EDITOR');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: dialogSelectedRole == 'EDITOR'
                                ? _aiPurple.withOpacity(0.08)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: dialogSelectedRole == 'EDITOR'
                                  ? _aiPurple
                                  : Colors.grey[200]!,
                              width: dialogSelectedRole == 'EDITOR' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: dialogSelectedRole == 'EDITOR'
                                    ? _aiPurple
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
                              if (dialogSelectedRole == 'EDITOR')
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _aiPurple,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Role selector option 2: VIEWER
                      GestureDetector(
                        onTap: () {
                          setDialogState(() => dialogSelectedRole = 'VIEWER');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: dialogSelectedRole == 'VIEWER'
                                ? _aiPurple.withOpacity(0.08)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: dialogSelectedRole == 'VIEWER'
                                  ? _aiPurple
                                  : Colors.grey[200]!,
                              width: dialogSelectedRole == 'VIEWER' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 18,
                                color: dialogSelectedRole == 'VIEWER'
                                    ? _aiPurple
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
                              if (dialogSelectedRole == 'VIEWER')
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _aiPurple,
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
                          backgroundColor: _aiPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final email = _companionInputController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() {
                              emailErrorMessage = 'Email không hợp lệ!';
                            });
                            return;
                          }

                          setState(() {
                            _invitedCompanionsList.add(
                              InvitedCompanion(
                                email: email,
                                role: dialogSelectedRole,
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
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  String _getStepTitleLabel(int step) {
    switch (step) {
      case 0:
        return 'Tên chuyến đi';
      case 1:
        return 'Ngày khởi hành';
      case 2:
        return 'Dự kiến ngân sách';
      case 3:
        return 'Bạn đồng hành';
      case 4:
        return 'Danh mục chuyến đi';
      case 5:
        return 'Yêu cầu riêng cho AI';
      default:
        return '';
    }
  }

  String _getPrimaryButtonText() {
    switch (_currentStep) {
      case 0:
      case 1:
      case 2:
        return 'Tiếp tục';
      case 3:
        return (_privacyLevel == 'Riêng tư' || _invitedCompanionsList.isEmpty)
            ? 'Tiếp tục'
            : 'Mời bạn đồng hành';
      case 4:
        return 'Tiếp tục';
      case 5:
        return 'Tạo Lịch Trình AI';
      default:
        return 'Tiếp tục';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = _isCreating
        ? MediaQuery.of(context).size.height
        : MediaQuery.of(context).size.height * 0.94;

    final BorderRadius borderRadius = _isCreating
        ? BorderRadius.zero
        : const BorderRadius.vertical(top: Radius.circular(28));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: sheetHeight,
      decoration: BoxDecoration(
        color: _isCreating ? const Color(0xFF0F0C20) : Colors.white,
        borderRadius: borderRadius,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header Bar (Matches Manual Itinerary Header Exactly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Back / Close Icon Container
                    GestureDetector(
                      onTap: () {
                        if (_currentStep > 0) {
                          _previousStep();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _currentStep > 0
                              ? Icons.arrow_back_rounded
                              : Icons.close_rounded,
                          size: 20,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Progress Segmented Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getStepTitleLabel(_currentStep),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _aiPurple,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _aiPurple.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_currentStep + 1}/$_totalSteps',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _aiPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(_totalSteps, (index) {
                              final isActive = index <= _currentStep;
                              final isCurrent = index == _currentStep;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: isCurrent ? 5 : 3.5,
                                  margin: EdgeInsets.only(
                                    right: index == _totalSteps - 1 ? 0 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _aiPurple
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Top Close Icon Container
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Wizard Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (step) => setState(() => _currentStep = step),
                  children: [
                    _buildStep0TripNameAndDestination(),
                    _buildStep1Dates(),
                    _buildStep5Budget(),
                    _buildStep4Companions(),
                    _buildStep2Categories(),
                    _buildStep6CustomRequest(),
                  ],
                ),
              ),

              // Bottom Action Bar (Identical to Manual Itinerary Creation)
              _buildBottomBar(),
            ],
          ),

          // AI Fullscreen Loading Overlay with Progress Bar & Processing Steps
          if (_isCreating) _buildFullscreenAILoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildFullscreenAILoadingOverlay() {
    final currentStepData =
        _aiLoadingSteps[_activeStepIndex.clamp(0, _aiLoadingSteps.length - 1)];
    final percentInt = (_creationProgress * 100).clamp(0, 100).toInt();

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0C20), Color(0xFF1B0B38), Color(0xFF2E0949)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // Glowing Pulsing Central AI Sphere Graphic
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient Outer Glow Ring
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _aiPurple.withOpacity(0.4),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),

                        // Animated Gradient Core Icon Container
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_aiPurple, _aiPurpleDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // App AI Title & Destination Info
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFE2E8F0)],
                      ).createShader(bounds),
                      child: const Text(
                        'CloudMood AI Assistant',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đang thiết kế hành trình ${_selectedDestination.isNotEmpty ? _selectedDestination : "du lịch"} ($_days ngày)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Progress Bar & Percentage Pill Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            currentStepData['title']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _aiPurple.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _aiPurple.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            '$percentInt%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE0E7FF),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Smooth Custom Progress Bar Indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: _creationProgress,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _aiPurple,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      currentStepData['desc']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Step-by-Step Processing Timeline Checklist Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: List.generate(_aiLoadingSteps.length, (
                          index,
                        ) {
                          final step = _aiLoadingSteps[index];
                          final isDone = index < _activeStepIndex;
                          final isCurrent = index == _activeStepIndex;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                // Icon Indicator
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDone
                                        ? const Color(0xFF10B981)
                                        : (isCurrent
                                              ? _aiPurple
                                              : Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Center(
                                    child: isDone
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          )
                                        : (isCurrent
                                              ? const SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white
                                                        .withOpacity(0.5),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    step['title']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isDone || isCurrent
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // BOTTOM ACTION BAR (Identical to Manual Itinerary Creation)
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Hero Action Button (Full Width Gradient/Blue Button)
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _aiPurple.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _nextStep,
                child: Center(
                  child: Row(
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
                        _currentStep == 5
                            ? Icons.auto_awesome_rounded
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

          // Secondary Skip Button for Companion Step (Step 4)
          if (_currentStep == 4) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _nextStep,
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

  // STEP 0: Trip Name & Destination Selection (Identical to Manual Itinerary Creation)
  Widget _buildStep0TripNameAndDestination() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            ).createShader(bounds),
            child: const Text(
              'Hành trình của bạn\nbắt đầu từ đây',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đặt một cái tên thật ý nghĩa và chọn điểm đến bạn dự định ghé thăm.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          // Trip Name TextField
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _aiPurple.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _tripTitleController,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
              onChanged: (val) {
                _userEditedTitle = true;
              },
              decoration: InputDecoration(
                hintText: _selectedDestination.isNotEmpty
                    ? 'Chuyến đi $_selectedDestination AI'
                    : 'Nhập tên chuyến đi...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(
                  Icons.card_travel_rounded,
                  color: _aiPurple,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
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
                  borderSide: const BorderSide(color: _aiPurple, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Destination Search Bar
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
              controller: _destinationSearchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm: Cần Thơ, Đà Nẵng, Hà Nội...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: _aiPurple),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
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
                  borderSide: const BorderSide(color: _aiPurple, width: 1.5),
                ),
                suffixIcon: _destinationSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _destinationSearchController.clear();
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
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: _aiPurple)),
          ],

          // Search Results List
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length > 5
                      ? 5
                      : _searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
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
                          color: _aiPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _aiPurple,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        formatted,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _destinationSearchController.text = name;
                        _searchResults = [];
                        _selectDestination(name);
                      },
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Text(
            'Điểm đến phổ biến',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _popularDestinations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final dest = _popularDestinations[index];
              final isSelected =
                  _selectedDestination == dest['name'] &&
                  _destinationSearchController.text.trim().isEmpty;

              return InkWell(
                onTap: () {
                  _destinationSearchController.clear();
                  _selectDestination(dest['name']!);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _aiPurple.withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _aiPurple : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _aiPurple.withOpacity(0.12)
                              : _aiPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _aiPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dest['name']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? _aiPurple
                                    : AppTheme.darkText,
                              ),
                            ),
                            Text(
                              dest['desc']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: _aiPurple,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // STEP 1: Dates Selection (Identical to manual itinerary + Max 7 Days Limit)
  Widget _buildStep1Dates() {
    final now = DateTime.now();
    final monthsList = List.generate(24, (index) {
      return DateTime(now.year, now.month + index, 1);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
              const SizedBox(height: 4),
              Text(
                'Lịch trình AI hỗ trợ tối đa 7 ngày để tối ưu hóa địa điểm',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              // Date Range Summary Banner
              if (_selectedDateRange != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _aiPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _aiPurple.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: _aiPurple,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _aiPurple,
                            ),
                          ),
                          Text(
                            'Tổng thời gian: $_days ngày',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Scrollable Calendar Grid
        Expanded(
          child: ListView.builder(
            controller: _calendarScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: monthsList.length,
            itemBuilder: (context, index) {
              final monthDate = monthsList[index];
              final isCurrentMonth =
                  monthDate.year == now.year && monthDate.month == now.month;
              return Padding(
                key: isCurrentMonth ? _currentMonthKey : null,
                padding: const EdgeInsets.only(bottom: 20),
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
    final daysInMonth = DateUtils.getDaysInMonth(
      monthDate.year,
      monthDate.month,
    );
    final firstWeekday =
        DateTime(monthDate.year, monthDate.month, 1).weekday % 7;
    final weekDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              monthName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays
              .map(
                (day) => SizedBox(
                  width: 36,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
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
            if (index < firstWeekday) return const SizedBox.shrink();

            final dayNumber = index - firstWeekday + 1;
            final cellDate = DateTime(
              monthDate.year,
              monthDate.month,
              dayNumber,
            );
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final isPast = cellDate.isBefore(today);

            bool isStart =
                _selectedDateRange != null &&
                DateUtils.isSameDay(_selectedDateRange!.start, cellDate);
            bool isEnd =
                _selectedDateRange != null &&
                DateUtils.isSameDay(_selectedDateRange!.end, cellDate);
            bool isInRange =
                _selectedDateRange != null &&
                cellDate.isAfter(_selectedDateRange!.start) &&
                cellDate.isBefore(_selectedDateRange!.end);

            final isToday = DateUtils.isSameDay(today, cellDate);

            return GestureDetector(
              key: isStart ? _selectedDateKey : null,
              onTap: isPast ? null : () => _onDateCellTapped(cellDate),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: (isStart || isEnd)
                      ? _aiPurple
                      : (isInRange
                            ? _aiPurple.withOpacity(0.12)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(
                    (isStart || isEnd) ? 30 : 8,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (isStart || isEnd || isToday)
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isStart || isEnd
                          ? Colors.white
                          : (isInRange
                                ? _aiPurple
                                : (isPast
                                      ? Colors.grey.shade300
                                      : (isToday
                                            ? _aiPurple
                                            : AppTheme.darkText))),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryLeading(dynamic cat, bool isSelected) {
    Color iconColor = isSelected ? Colors.white : _aiPurple;
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
          color: iconColor,
        );
      }

      final String name = (cat['name'] ?? '').toString().toLowerCase();
      if (cat['emoji'] != null &&
          cat['emoji'].toString().isNotEmpty &&
          cat['emoji'] != '📍') {
        return Text(
          cat['emoji'].toString(),
          style: const TextStyle(fontSize: 18),
        );
      }

      if (name.contains('nhà hàng'))
        return Icon(Icons.restaurant_rounded, size: 18, color: iconColor);
      if (name.contains('khách sạn'))
        return Icon(Icons.hotel_rounded, size: 18, color: iconColor);
      if (name.contains('quán ăn'))
        return Icon(Icons.fastfood_rounded, size: 18, color: iconColor);
      if (name.contains('cà phê') || name.contains('cafe'))
        return Icon(Icons.local_cafe_rounded, size: 18, color: iconColor);
      if (name.contains('trung tâm thương mại') || name.contains('mua sắm'))
        return Icon(Icons.shopping_bag_rounded, size: 18, color: iconColor);
      if (name.contains('công viên') || name.contains('thiên nhiên'))
        return Icon(Icons.park_rounded, size: 18, color: iconColor);
      if (name.contains('bảo tàng') || name.contains('văn hóa'))
        return Icon(Icons.museum_rounded, size: 18, color: iconColor);
      if (name.contains('điểm tham quan') || name.contains('tham quan'))
        return Icon(Icons.tour_rounded, size: 18, color: iconColor);
      if (name.contains('bar') || name.contains('đêm'))
        return Icon(Icons.local_bar_rounded, size: 18, color: iconColor);
      if (name.contains('check-in') || name.contains('sống ảo'))
        return Icon(Icons.camera_alt_rounded, size: 18, color: iconColor);
    }
    return Icon(Icons.location_on_rounded, size: 18, color: iconColor);
  }

  // STEP 2: Categories (Sở thích chuyến đi - Matches Manual Itinerary 100%)
  Widget _buildStep2Categories() {
    final categoriesListToDisplay = _dbCategories.isNotEmpty
        ? _dbCategories
        : _defaultCategoriesData;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            ).createShader(bounds),
            child: const Text(
              'Danh mục chuyến đi',
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
            const Center(child: CircularProgressIndicator(color: _aiPurple))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categoriesListToDisplay.map((cat) {
                final String name = cat['name'].toString();
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
                              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
                                color: _aiPurple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCategoryLeading(cat, isSelected),
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
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // STEP 3: Pace Selection (Nhịp độ chuyến đi - Separated into its own step!)
  Widget _buildStep3Pace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            ).createShader(bounds),
            child: const Text(
              'Nhịp độ chuyến đi',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn tần suất di chuyển để AI biết cần tạo bao nhiêu địa điểm cho mỗi ngày.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paces.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pace = _paces[index];
              final isSelected = _selectedPace == pace['name'];

              return InkWell(
                onTap: () => setState(() => _selectedPace = pace['name']!),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _aiPurple.withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _aiPurple : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pace['name']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? _aiPurple
                                    : AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pace['desc']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value: pace['name']!,
                        groupValue: _selectedPace,
                        activeColor: _aiPurple,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPace = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // STEP 4: Companions & Privacy (Identical to manual itinerary)
  Widget _buildStep4Companions() {
    final privacyOptions = [
      {
        'title': 'Riêng tư',
        'desc': 'Chỉ mình bạn có thể xem hành trình này',
        'icon': Icons.lock_rounded,
      },
      {
        'title': 'Thành viên',
        'desc': 'Chỉ bạn và những người được mời tham gia',
        'icon': Icons.group_rounded,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
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
          const SizedBox(height: 6),
          Text(
            'Thêm người đi cùng và chọn mức độ riêng tư cho chuyến đi.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          const Text(
            'Mức độ riêng tư chuyến đi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Column(
            children: privacyOptions.map((opt) {
              final isSelected = _privacyLevel == opt['title'];
              return InkWell(
                onTap: () =>
                    setState(() => _privacyLevel = opt['title'] as String),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _aiPurple.withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _aiPurple : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        opt['icon'] as IconData,
                        color: isSelected ? _aiPurple : Colors.grey,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['title'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? _aiPurple
                                    : AppTheme.darkText,
                              ),
                            ),
                            Text(
                              opt['desc'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value: opt['title'] as String,
                        groupValue: _privacyLevel,
                        activeColor: _aiPurple,
                        onChanged: (val) {
                          if (val != null) setState(() => _privacyLevel = val);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          if (_privacyLevel == 'Thành viên') ...[
            const SizedBox(height: 16),
            // Add Companion Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
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
                          color: _aiPurple.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: _aiPurple,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thêm người đi cùng',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Thêm bạn đồng hành để hệ thống tự động gửi thư mời tham gia với phân quyền tương ứng.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_invitedCompanionsList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Column(
                      children: _invitedCompanionsList.map((companion) {
                        final isEditor = companion.role == 'EDITOR';
                        return Dismissible(
                          key: Key(companion.email),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            setState(() {
                              _invitedCompanionsList.remove(companion);
                            });
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _aiPurple,
                                  backgroundImage:
                                      (companion.avatar != null &&
                                          companion.avatar!.isNotEmpty)
                                      ? NetworkImage(companion.avatar!)
                                      : null,
                                  child:
                                      (companion.avatar == null ||
                                          companion.avatar!.isEmpty)
                                      ? const Icon(
                                          Icons.person_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (companion.fullName != null &&
                                          companion.fullName!.isNotEmpty)
                                        Text(
                                          companion.fullName!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      Text(
                                        companion.email,
                                        style: TextStyle(
                                          fontSize: companion.fullName != null
                                              ? 11
                                              : 13,
                                          color: companion.fullName != null
                                              ? Colors.grey[600]
                                              : AppTheme.darkText,
                                          fontWeight: companion.fullName != null
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isEditor
                                        ? _aiPurple.withOpacity(0.1)
                                        : Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isEditor ? 'Chỉnh sửa' : 'Chỉ xem',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isEditor
                                          ? _aiPurple
                                          : Colors.amber[800],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _aiPurple.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
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
          ],
        ],
      ),
    );
  }

  // STEP 5: Budget & Currency (Single values for total trip)
  Widget _buildStep5Budget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            ).createShader(bounds),
            child: const Text(
              'Dự kiến ngân sách chuyến đi',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tổng ngân sách dự kiến cho cả chuyến đi ($_days ngày)',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Selector Preset vs Custom
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      'Mức chọn sẵn',
                      style: TextStyle(
                        fontFamily: 'SDK_SC_Web-Heavy',
                        color: !_useCustomBudget
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  selected: !_useCustomBudget,
                  selectedColor: _aiPurple,
                  labelStyle: TextStyle(
                    fontFamily: 'SDK_SC_Web-Heavy',
                    color: !_useCustomBudget ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _useCustomBudget = false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      'Tự nhập số tiền',
                      style: TextStyle(
                        fontFamily: 'SDK_SC_Web-Heavy',
                        color: _useCustomBudget ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  selected: _useCustomBudget,
                  selectedColor: _aiPurple,
                  labelStyle: TextStyle(
                    fontFamily: 'SDK_SC_Web-Heavy',
                    color: _useCustomBudget ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _useCustomBudget = true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!_useCustomBudget) ...[
            _buildBudgetPresetCard('Tiết kiệm 💵', '3.000.000 VNĐ / chuyến đi'),
            const SizedBox(height: 12),
            _buildBudgetPresetCard('Vừa phải 💳', '7.000.000 VNĐ / chuyến đi'),
            const SizedBox(height: 12),
            _buildBudgetPresetCard(
              'Sang trọng 💎',
              '15.000.000 VNĐ / chuyến đi',
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập tổng ngân sách cho cả chuyến đi:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customBudgetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '7,000,000',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            items: _currencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCurrency = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // STEP 6: Custom Request for OpenAI GPT
  Widget _buildStep6CustomRequest() {
    final List<String> exampleRequests = [
      'Yêu thích thiên nhiên, không khí trong lành và ngắm cảnh',
      'Thích thưởng thức ẩm thực đặc sản địa phương',
      'Thích check-in sống ảo, nhiều góc chụp hình đẹp',
      'Du lịch tâm linh, viếng chùa, đền và cầu bình an',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Header with AI badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      ).createShader(bounds),
                      child: const Text(
                        'Yêu cầu riêng của bạn',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tùy chọn — OpenAI GPT sẽ cá nhân hóa lịch trình theo yêu cầu',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'OpenAI GPT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main text field
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF8E2DE2).withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _customRequestController,
              maxLines: 4,
              maxLength: 250,
              style: const TextStyle(fontSize: 15, height: 1.5),
              decoration: InputDecoration(
                hintText:
                    'VD: Đi với người già, không muốn đi bộ nhiều, thích quán yên tĩnh và không khí trong lành...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFF8E2DE2),
                    width: 2,
                  ),
                ),
                counterStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Example chips
          const Text(
            'Ghi chú nhanh:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: exampleRequests.map((example) {
              final isSelected = _customRequestController.text == example;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _customRequestController.clear();
                    } else {
                      _customRequestController.text = example;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8E2DE2)
                        : const Color(0xFF8E2DE2).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(
                        0xFF8E2DE2,
                      ).withOpacity(isSelected ? 1.0 : 0.3),
                    ),
                  ),
                  child: Text(
                    example,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8E2DE2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Skip note
          Center(
            child: Text(
              'Bạn có thể bỏ qua bước này — AI vẫn tạo lịch trình dựa trên các lựa chọn trước',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBudgetPresetCard(String levelName, String desc) {
    String levelKey = 'Vừa phải';
    if (levelName.contains('Tiết kiệm')) {
      levelKey = 'Tiết kiệm';
    } else if (levelName.contains('Sang trọng')) {
      levelKey = 'Sang trọng';
    } else if (levelName.contains('Vừa phải')) {
      levelKey = 'Vừa phải';
    } else {
      levelKey = levelName.split(' ')[0];
    }
    final isSelected = _selectedBudgetLevel == levelKey;

    return InkWell(
      onTap: () => setState(() => _selectedBudgetLevel = levelKey),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _aiPurple.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _aiPurple : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    levelName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _aiPurple : AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: levelKey,
              groupValue: _selectedBudgetLevel,
              activeColor: _aiPurple,
              onChanged: (val) {
                if (val != null) setState(() => _selectedBudgetLevel = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
