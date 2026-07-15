import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class CreateItineraryWizardSheet extends StatefulWidget {
  final int userId;

  const CreateItineraryWizardSheet({super.key, required this.userId});

  @override
  State<CreateItineraryWizardSheet> createState() =>
      _CreateItineraryWizardSheetState();
}

class _CreateItineraryWizardSheetState
    extends State<CreateItineraryWizardSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1: Basic constraints
  final _titleController = TextEditingController();
  String _selectedDestination = '';
  DateTimeRange? _selectedDateRange;
  int _days = 3;
  double _budget = 3000000;

  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  final _searchController = TextEditingController();

  final List<Map<String, String>> _popularDestinations = [
    {
      'name': 'Đà Nẵng',
      'image':
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Hội An',
      'image':
          'https://images.unsplash.com/photo-1528127269322-539801943592?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Nha Trang',
      'image':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Đà Lạt',
      'image':
          'https://images.unsplash.com/photo-1583244532610-2a234e7c3eca?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Phuket',
      'image':
          'https://images.unsplash.com/photo-1589308078059-be1415eab4c3?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Bali',
      'image':
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Singapore',
      'image':
          'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=200&auto=format&fit=crop&q=80',
    },
  ];

  // Step 2: Preferences & Style
  final List<String> _selectedCategories = [];
  String _selectedCompanion = 'Solo';

  // Step 3: Pace & Amenities
  String _selectedPace = 'Balanced';
  final List<String> _selectedAmenities = [];

  // Options Data
  final List<String> _destinations = [
    'Đà Nẵng',
    'Hội An',
    'Nha Trang',
    'Đà Lạt',
    'Phú Quốc',
    'Bali',
    'Singapore',
    'Phuket',
  ];

  final List<Map<String, dynamic>> _budgetLevels = [
    {'label': 'Tiết kiệm', 'value': 1000000},
    {'label': 'Trung bình', 'value': 3000000},
    {'label': 'Sang trọng', 'value': 10000000},
    {'label': 'Tùy chỉnh', 'value': -1},
  ];
  String _selectedBudgetLevel = 'Trung bình';

  final List<Map<String, dynamic>> _categoriesList = [
    {'name': 'Ẩm thực', 'icon': Icons.restaurant_rounded},
    {'name': 'Văn hóa - Lịch sử', 'icon': Icons.museum_rounded},
    {'name': 'Khám phá thiên nhiên', 'icon': Icons.forest_rounded},
    {'name': 'Vui chơi giải trí', 'icon': Icons.sports_esports_rounded},
    {'name': 'Check-in sống ảo', 'icon': Icons.camera_alt_rounded},
    {'name': 'Thư giãn / Cafe', 'icon': Icons.local_cafe_rounded},
  ];

  final List<Map<String, dynamic>> _companionsList = [
    {
      'id': 'Solo',
      'title': 'Một mình',
      'subtitle': 'Khám phá độc lập',
      'icon': Icons.person_rounded,
    },
    {
      'id': 'Couple',
      'title': 'Cặp đôi',
      'subtitle': 'Lãng mạn & gắn kết',
      'icon': Icons.favorite_rounded,
    },
    {
      'id': 'Family',
      'title': 'Gia đình',
      'subtitle': 'Phù hợp trẻ nhỏ & người già',
      'icon': Icons.family_restroom_rounded,
    },
    {
      'id': 'Friends',
      'title': 'Nhóm bạn',
      'subtitle': 'Vui nhộn & năng động',
      'icon': Icons.group_rounded,
    },
  ];

  final List<Map<String, dynamic>> _pacesList = [
    {
      'id': 'Relaxed',
      'title': 'Thư thả / Nghỉ dưỡng',
      'desc': 'Đi ít điểm, thời gian lưu lại lâu, ưu tiên nghỉ ngơi.',
      'icon': Icons.spa_rounded,
    },
    {
      'id': 'Balanced',
      'title': 'Cân bằng',
      'desc': 'Kết hợp vừa tham quan vừa nghỉ dưỡng hợp lý.',
      'icon': Icons.balance_rounded,
    },
    {
      'id': 'Active',
      'title': 'Khám phá tối đa',
      'desc': 'Lịch trình dày đặc, đi được nhiều nơi nhất có thể.',
      'icon': Icons.explore_rounded,
    },
  ];

  final List<String> _amenitiesList = [
    'Ăn chay',
    'Có chỗ đậu xe ô tô',
    'Không gian ngoài trời',
    'Thân thiện với thú cưng',
    'Bể bơi',
    'Spa',
    'Wifi miễn phí',
    'Bar/Pub',
    'Trung tâm Gym',
  ];

  @override
  void initState() {
    super.initState();
    // Default date range (today to 3 days later)
    _selectedDateRange = DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now().add(const Duration(days: 2)),
    );
    _days = 3;
    _titleController.text = '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
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
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchDestination(String query) async {
    setState(() {
      _isLoadingSearch = true;
    });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
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
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _selectDestination(String destinationName) async {
    setState(() {
      _isSaving = true;
    });

    final isSupported = await DatabaseService().isDestinationSupported(
      destinationName,
    );

    setState(() {
      _isSaving = false;
    });

    if (isSupported) {
      setState(() {
        _selectedDestination = destinationName;
        _titleController.text = 'Khám phá $destinationName';
        _nextStep();
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
              'Rất tiếc, CloudMood hiện chưa hỗ trợ thiết lập lịch trình tự động tại "$destinationName".\n\n'
              'Hãy thử trải nghiệm các địa điểm đã có sẵn dữ liệu của chúng tôi như: Đà Nẵng, Hà Nội, Hội An, Đà Lạt, Bali, Singapore...',
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

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      double m = amount / 1000000.0;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)} triệu đ';
    } else if (amount >= 1000) {
      double k = amount / 1000.0;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k đ';
    }
    return '${amount.toInt()} đ';
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedDestination.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn điểm đến chuyến đi!')),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên chuyến đi!')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_selectedCategories.length < 2 || _selectedCategories.length > 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn từ 2 đến 4 trải nghiệm mong muốn!'),
          ),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveItinerary();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveItinerary() async {
    setState(() => _isSaving = true);
    try {
      final result = await DatabaseService().createUserItinerary(
        userId: widget.userId,
        title: _titleController.text.trim(),
        destination: _selectedDestination,
        startDate: _selectedDateRange?.start ?? DateTime.now(),
        days: _days,
        budget: _budget.toInt(),
        companion: _selectedCompanion,
        pace: _selectedPace,
        categories: _selectedCategories,
        amenities: _selectedAmenities,
      );

      if (mounted) {
        if (result != null) {
          Navigator.of(context).pop(result);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã thêm hành trình mới thành công!'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Header Drag Handle & Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lên kế hoạch chuyến đi',
                        style: AppTheme.sectionTitleStyle.copyWith(
                          color: AppTheme.primary,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.subtitleText,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 4,
                      minHeight: 6,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0Destination(),
                  _buildStep1HardRules(),
                  _buildStep2SoftRules(),
                  _buildStep3FineTuning(),
                ],
              ),
            ),

            // Bottom Action Panel
            Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  if (_currentStep > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(100, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      onPressed: _prevStep,
                      child: const Text(
                        'Quay lại',
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Next / Complete Button
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: _currentStep > 0 ? 12.0 : 0.0,
                      ),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isSaving ? null : _nextStep,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _currentStep == 3
                                    ? 'Hoàn tất & Tạo lịch trình'
                                    : 'Tiếp tục',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: Basic constraints
  Widget _buildStep1HardRules() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Bước 1: Điểm đến & Ràng buộc cơ bản',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtitleText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Trip Title
          const Text('Tên chuyến đi của bạn?', style: AppTheme.bodyBoldStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: AppTheme.inputDecoration(
              hintText: 'Ví dụ: Hè rực rỡ tại Đà Nẵng',
              prefixIcon: Icons.edit_road_rounded,
            ),
          ),
          const SizedBox(height: 20),

          // Destination display
          const Text('Điểm đến của bạn', style: AppTheme.bodyBoldStyle),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(
                  _selectedDestination.isNotEmpty
                      ? _selectedDestination
                      : 'Chưa chọn',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Trip Duration (Date Range)
          const Text(
            'Thời gian chuyến đi của bạn?',
            style: AppTheme.bodyBoldStyle,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final pickedRange = await showDateRangePicker(
                context: context,
                initialDateRange: _selectedDateRange,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primary,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: AppTheme.darkText,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedRange != null) {
                setState(() {
                  _selectedDateRange = pickedRange;
                  _days =
                      pickedRange.end.difference(pickedRange.start).inDays + 1;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.subtitleText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDateRange == null
                          ? 'Chọn khoảng thời gian đi'
                          : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year} ($_days ngày)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: AppTheme.subtitleText,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Budget selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ngân sách dự kiến?', style: AppTheme.bodyBoldStyle),
              Text(
                _formatCurrency(_budget),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _budgetLevels.map((level) {
              final isSelected = _selectedBudgetLevel == level['label'];
              return ChoiceChip(
                label: Text(level['label']),
                selected: isSelected,
                selectedColor: AppTheme.primaryPeach,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.darkText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: AppTheme.lightGray,
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() {
                      _selectedBudgetLevel = level['label'];
                      if (level['value'] != -1) {
                        _budget = (level['value'] as int).toDouble();
                      }
                    });
                  }
                },
              );
            }).toList(),
          ),
          if (_selectedBudgetLevel == 'Tùy chỉnh') ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: AppTheme.border,
                thumbColor: AppTheme.primary,
                overlayColor: AppTheme.primary.withAlpha(40),
                valueIndicatorColor: AppTheme.primary,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: _budget,
                min: 500000,
                max: 30000000,
                divisions: 59,
                label: _formatCurrency(_budget),
                onChanged: (value) {
                  setState(() {
                    _budget = value;
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // STEP 2: Preferences & Style
  Widget _buildStep2SoftRules() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Bước 2: Sở thích & Phong cách trải nghiệm',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtitleText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Categories Select (Tag Chips)
          const Text(
            'Bạn muốn trải nghiệm những gì? (Chọn 2 - 4 mục)',
            style: AppTheme.bodyBoldStyle,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categoriesList.map((cat) {
              final isSelected = _selectedCategories.contains(cat['name']);
              return FilterChip(
                avatar: Icon(
                  cat['icon'] as IconData,
                  size: 16,
                  color: isSelected ? AppTheme.primary : AppTheme.subtitleText,
                ),
                label: Text(cat['name']),
                selected: isSelected,
                selectedColor: AppTheme.primaryPeach,
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.darkText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: AppTheme.lightGray,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      if (_selectedCategories.length < 4) {
                        _selectedCategories.add(cat['name']);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chỉ được chọn tối đa 4 trải nghiệm!',
                            ),
                          ),
                        );
                      }
                    } else {
                      _selectedCategories.remove(cat['name']);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Companion Select
          const Text('Bạn đi du lịch cùng ai?', style: AppTheme.bodyBoldStyle),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _companionsList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final comp = _companionsList[index];
              final isSelected = _selectedCompanion == comp['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCompanion = comp['id'];
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryPeach : Colors.white,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        comp['icon'] as IconData,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.subtitleText,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comp['title'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              comp['subtitle'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primary,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // STEP 3: Pace & Amenities
  Widget _buildStep3FineTuning() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Bước 3: Nhịp độ & Yêu cầu tiện ích',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtitleText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Pace Selection
          const Text(
            'Nhịp độ chuyến đi mong muốn?',
            style: AppTheme.bodyBoldStyle,
          ),
          const SizedBox(height: 12),
          Column(
            children: _pacesList.map((pace) {
              final isSelected = _selectedPace == pace['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPace = pace['id'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryPeach : Colors.white,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        pace['icon'] as IconData,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.subtitleText,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pace['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pace['desc'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Amenities Selection (Tag Chips)
          const Text(
            'Bạn có yêu cầu đặc biệt nào không?',
            style: AppTheme.bodyBoldStyle,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amenitiesList.map((amenity) {
              final isSelected = _selectedAmenities.contains(amenity);
              return FilterChip(
                label: Text(amenity),
                selected: isSelected,
                selectedColor: AppTheme.primaryPeach,
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.darkText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: AppTheme.lightGray,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedAmenities.add(amenity);
                    } else {
                      _selectedAmenities.remove(amenity);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep0Destination() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Bước 1: Chọn điểm đến',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.subtitleText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn muốn đi du lịch ở đâu?',
            style: AppTheme.bodyBoldStyle,
          ),
          const SizedBox(height: 12),

          // Search input field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration:
                AppTheme.inputDecoration(
                  hintText: 'Nhập thành phố, vùng miền...',
                  prefixIcon: Icons.search_rounded,
                ).copyWith(
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppTheme.subtitleText,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                        )
                      : null,
                ),
          ),

          if (_isLoadingSearch) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ],

          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Gợi ý tìm kiếm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.subtitleText,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: AppTheme.border),
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
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primary,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      subtitle: Text(
                        formatted,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtitleText,
                        ),
                      ),
                      onTap: () {
                        _selectDestination(name);
                      },
                    ),
                  );
                },
              ),
            ),
          ] else if (!_isLoadingSearch) ...[
            const SizedBox(height: 24),
            const Text('Điểm đến phổ biến', style: AppTheme.bodyBoldStyle),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: _popularDestinations.length,
              itemBuilder: (context, index) {
                final dest = _popularDestinations[index];
                final String name = dest['name']!;
                final String imageUrl = dest['image']!;

                return GestureDetector(
                  onTap: () {
                    _selectDestination(name);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withAlpha(80),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
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
}
