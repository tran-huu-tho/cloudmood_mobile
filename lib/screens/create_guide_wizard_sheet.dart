import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class CreateGuideWizardSheet extends StatefulWidget {
  final int userId;

  const CreateGuideWizardSheet({super.key, required this.userId});

  @override
  State<CreateGuideWizardSheet> createState() => _CreateGuideWizardSheetState();
}

class _CreateGuideWizardSheetState extends State<CreateGuideWizardSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  String _selectedDestination = '';

  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  bool _isLoadingPlaces = false;
  List<Map<String, dynamic>> _placesForDestination = [];
  final _searchController = TextEditingController();

  final List<Map<String, String>> _popularDestinations = [
    {
      'name': 'Đà Nẵng',
      'image': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Hội An',
      'image': 'https://images.unsplash.com/photo-1528127269322-539801943592?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Nha Trang',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Đà Lạt',
      'image': 'https://images.unsplash.com/photo-1583244532610-2a234e7c3eca?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Phuket',
      'image': 'https://images.unsplash.com/photo-1589308078059-be1415eab4c3?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Bali',
      'image': 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Singapore',
      'image': 'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Hà Nội',
      'image': 'https://images.unsplash.com/photo-1591222405459-a1e2e0e5e97d?w=200&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Hồ Chí Minh',
      'image': 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=200&auto=format&fit=crop&q=80',
    },
  ];

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
      setState(() => _isLoadingSearch = false);
    }
  }

  Future<void> _loadPlacesForDestination(String destination) async {
    setState(() {
      _isLoadingPlaces = true;
      _placesForDestination = [];
    });
    try {
      final places = await DatabaseService().fetchPlacesByDestination(destination);
      if (mounted) {
        setState(() => _placesForDestination = places);
      }
    } catch (e) {
      debugPrint('Error loading places: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  void _goNext() {
    if (_currentStep == 0) {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên hướng dẫn'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }
    if (_currentStep < 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _saveGuide();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
    try {
      final result = await DatabaseService().createUserItinerary(
        userId: widget.userId,
        title: _titleController.text.trim(),
        destination: _selectedDestination,
        startDate: DateTime.now(),
        days: 1,
        budget: 0,
        companion: '',
        pace: '',
        categories: [],
        amenities: [],
        isGuide: true,
      );

      if (mounted) {
        if (result != null) {
          Navigator.of(context).pop(result);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tạo hướng dẫn mới!'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        'Tạo Hướng dẫn mới',
                        style: AppTheme.sectionTitleStyle.copyWith(
                          color: AppTheme.amber,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppTheme.subtitleText),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 2,
                      minHeight: 6,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.amber),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bước ${_currentStep + 1} / 2',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
                      ),
                      Text(
                        _currentStep == 0 ? 'Đặt tên' : 'Chọn điểm đến',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtitleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(color: AppTheme.border, height: 1),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0Title(),
                  _buildStep1Destination(),
                ],
              ),
            ),

            // Bottom action
            Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: _goBack,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'Quay lại',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.subtitleText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isSaving ? null : _goNext,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _currentStep == 1 ? 'Tạo hướng dẫn' : 'Tiếp theo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
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

  // ─── Step 0: Title ───────────────────────────────────────────────────────────
  Widget _buildStep0Title() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📝 Đặt tên cho hướng dẫn',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Một cái tên hay sẽ giúp người đọc biết ngay đây là hướng dẫn về gì.',
            style: TextStyle(fontSize: 14, color: AppTheme.subtitleText),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 80,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.darkText),
            decoration: AppTheme.inputDecoration(
              hintText: 'VD: Khám phá Đà Nẵng từ A-Z',
              prefixIcon: Icons.menu_book_rounded,
            ).copyWith(
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.amber, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: AppTheme.amber, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Gợi ý đặt tên',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.amber, fontSize: 13),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('• Kinh nghiệm du lịch Hội An 3 ngày', style: TextStyle(fontSize: 13, color: AppTheme.subtitleText)),
                Text('• Top 10 địa điểm không thể bỏ lỡ ở Đà Lạt', style: TextStyle(fontSize: 13, color: AppTheme.subtitleText)),
                Text('• Ăn gì khi đến Nha Trang?', style: TextStyle(fontSize: 13, color: AppTheme.subtitleText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Destination ─────────────────────────────────────────────────────
  Widget _buildStep1Destination() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📍 Chọn điểm đến',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.darkText),
              ),
              const SizedBox(height: 8),
              Text(
                'Hướng dẫn này nói về địa điểm nào?',
                style: TextStyle(fontSize: 14, color: AppTheme.subtitleText),
              ),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: AppTheme.inputDecoration(
                  hintText: 'Tìm kiếm thành phố, địa điểm...',
                  prefixIcon: Icons.search_rounded,
                ).copyWith(
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.amber, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // Search results or destinations + places
        Expanded(
          child: _isLoadingSearch
              ? const Center(child: CircularProgressIndicator(color: AppTheme.amber, strokeWidth: 2.5))
              : _searchResults.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, i) {
                        final r = _searchResults[i];
                        final name = r['display_name'] as String? ?? '';
                        final shortName = name.split(',').take(2).join(',').trim();
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.location_on_rounded, color: AppTheme.amber, size: 18),
                          ),
                          title: Text(shortName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                             style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDestination = shortName;
                              _searchResults = [];
                              _searchController.clear();
                            });
                            _loadPlacesForDestination(shortName);
                          },
                        ),
                        );
                      },
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        // Selected destination banner
                        if (_selectedDestination.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.amber, width: 2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppTheme.amber, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedDestination,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkText,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedDestination = '';
                                    _placesForDestination = [];
                                  }),
                                  child: Icon(Icons.close_rounded, color: AppTheme.subtitleText, size: 18),
                                ),
                              ],
                            ),
                          ),

                        // Popular destinations chips
                        Text(
                          'Điểm đến phổ biến',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.subtitleText),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _popularDestinations.map((dest) {
                            final isSelected = _selectedDestination == dest['name'];
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedDestination = dest['name']!);
                                _loadPlacesForDestination(dest['name']!);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.amber : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.amber : AppTheme.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place_rounded, size: 14,
                                        color: isSelected ? Colors.white : AppTheme.subtitleText),
                                    const SizedBox(width: 6),
                                    Text(
                                      dest['name']!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : AppTheme.darkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Places in selected destination
                        if (_selectedDestination.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 16, color: AppTheme.subtitleText),
                              const SizedBox(width: 6),
                              Text(
                                'Địa điểm ở $_selectedDestination',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.subtitleText,
                                ),
                              ),
                              if (_placesForDestination.isNotEmpty)
                                Text(
                                  ' (${_placesForDestination.length})',
                                  style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingPlaces)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(color: AppTheme.amber, strokeWidth: 2.5)),
                            )
                          else if (_placesForDestination.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Chưa có địa điểm nào trong khu vực này.',
                                style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.3,
                              ),
                              itemCount: _placesForDestination.length,
                              itemBuilder: (context, i) {
                                final place = _placesForDestination[i];
                                final imageUrl = place['image'] as String?;
                                final name = place['name'] as String? ?? '';
                                final address = place['address'] as String? ?? '';
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: AppTheme.surfaceVariant,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (imageUrl != null)
                                        Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceVariant),
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withAlpha(180)],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        right: 8,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (address.isNotEmpty)
                                              Text(
                                                address,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha(200),
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}
