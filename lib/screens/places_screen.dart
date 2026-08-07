import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import '../utils/string_utils.dart';
import 'package:latlong2/latlong.dart';
import 'map_picker_screen.dart';

class CloudmoodPlacesScreen extends StatefulWidget {
  final String? initialQuery;

  const CloudmoodPlacesScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<CloudmoodPlacesScreen> createState() => _CloudmoodPlacesScreenState();
}

class _CloudmoodPlacesScreenState extends State<CloudmoodPlacesScreen> {
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'Nổi bật';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingCategories = true;

  // Pagination State
  int _currentPage = 1;
  static const int _limit = 10;
  bool _hasMore = true;
  Timer? _debounce;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  final List<String> _uiPriceLevels = []; // 'cheap', 'moderate', 'expensive'
  double _selectedMinRating = 0.0;

  List<String> get _dbPriceLevels {
    final List<String> dbLevels = [];
    if (_uiPriceLevels.contains('cheap')) {
      dbLevels.addAll(['CHEAP', 'INEXPENSIVE', 'FREE', r'$', r'$$']);
    }
    if (_uiPriceLevels.contains('moderate')) {
      dbLevels.addAll(['MODERATE', r'$$$']);
    }
    if (_uiPriceLevels.contains('expensive')) {
      dbLevels.addAll(['EXPENSIVE', 'VERY_EXPENSIVE', r'$$$$', r'$$$$$']);
    }
    return dbLevels;
  }



  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!;
      _searchController.text = widget.initialQuery!;
    }
    _loadCategories();
    _loadPlaces(page: 1);
  }

  @override
  void didUpdateWidget(covariant CloudmoodPlacesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery && widget.initialQuery != null) {
      setState(() {
        _searchQuery = widget.initialQuery!;
        _searchController.text = widget.initialQuery!;
      });
      _loadPlaces(page: 1);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final fetched = await DatabaseService().getCategories();
      setState(() {
        _categories = fetched;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadPlaces({int page = 1}) async {
    setState(() {
      _currentPage = page;
      _isLoading = true;
    });

    try {
      final fetched = await DatabaseService().fetchPlaces(
        categoryName: _selectedCategory == 'Nổi bật' ? null : _selectedCategory,
        page: _currentPage,
        limit: _limit,
        query: _searchQuery.trim(),
        priceLevels: _dbPriceLevels.isNotEmpty ? _dbPriceLevels : null,
        minRating: _selectedMinRating > 0 ? _selectedMinRating : null,
      );

      setState(() {
        _places = fetched;
        _isLoading = false;
        _hasMore = fetched.length == _limit;
      });
    } catch (e) {
      debugPrint('Error loading places: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _displayPlaces {
    return _places;
  }



  void _showProposePlaceSheet(BuildContext context) {
    final user = AuthService().currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để đề xuất địa điểm mới!'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    
    int? selectedCategoryId;
    if (_categories.isNotEmpty) {
      selectedCategoryId = int.tryParse(_categories.first['id'].toString());
    }
    XFile? selectedImage;
    LatLng? selectedLatLng;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_location_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Đề xuất địa điểm mới',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Đóng góp địa điểm yêu thích của bạn',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF2563EB),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Địa điểm của bạn sẽ được gửi tới Admin phê duyệt trước khi xuất hiện công khai.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E40AF),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Place name
                        Text(
                          'Tên địa điểm *',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkText,
                          ),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Nhập tên địa điểm...',
                            prefixIcon: Icons.place_rounded,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty)
                              ? 'Vui lòng nhập tên địa điểm'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Address
                        Text(
                          'Địa chỉ *',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: addressController,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkText,
                          ),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Nhập địa chỉ chi tiết...',
                            prefixIcon: Icons.location_on_rounded,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty)
                              ? 'Vui lòng nhập địa chỉ'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Category Dropdown
                        Text(
                          'Danh mục *',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          dropdownColor: AppTheme.surface,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.darkText,
                            fontSize: 14,
                          ),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Chọn danh mục',
                            prefixIcon: Icons.category_rounded,
                          ),
                          items: _categories.map((cat) {
                            final id = int.parse(cat['id'].toString());
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                cat['name'] ?? '',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.darkText,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setSheetState(() {
                              selectedCategoryId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Vui lòng chọn danh mục' : null,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          'Mô tả *',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descController,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkText,
                          ),
                          maxLines: 3,
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Nhập mô tả ngắn về địa điểm này...',
                            prefixIcon: Icons.info_outline_rounded,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty)
                              ? 'Vui lòng nhập mô tả'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Price
                        Text(
                          'Giá tham khảo *',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: priceController,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkText,
                          ),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'VD: Miễn phí hoặc 50.000đ - 100.000đ',
                            prefixIcon: Icons.attach_money_rounded,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty)
                              ? 'Vui lòng nhập giá tham khảo'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Map Picker Button
                        Text(
                          'Vị trí trên bản đồ *',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final LatLng? result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapPickerScreen(
                                  initialPosition: selectedLatLng,
                                ),
                              ),
                            );
                            if (result != null) {
                              setSheetState(() {
                                selectedLatLng = result;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.map_rounded,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedLatLng != null
                                        ? '${selectedLatLng!.latitude.toStringAsFixed(6)}, ${selectedLatLng!.longitude.toStringAsFixed(6)}'
                                        : 'Chọn vị trí trên bản đồ *',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: selectedLatLng != null ? AppTheme.darkText : AppTheme.subtitleText,
                                      fontWeight: selectedLatLng != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.subtitleText,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Image Picker instead of URL input field
                        Text(
                          'Ảnh địa điểm',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 50,
                            );
                            if (image != null) {
                              setSheetState(() {
                                selectedImage = image;
                              });
                            }
                          },
                          child: selectedImage != null
                              ? Stack(
                                  children: [
                                    Container(
                                      height: 150,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: FileImage(File(selectedImage!.path)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setSheetState(() {
                                            selectedImage = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.border,
                                      style: BorderStyle.solid,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: AppTheme.primary,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Chọn ảnh từ điện thoại',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () async {
                                  if (formKey.currentState!.validate()) {
                                    if (selectedLatLng == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Vui lòng chọn vị trí trên bản đồ!'),
                                          backgroundColor: AppTheme.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final name = nameController.text.trim();
                                    final address = addressController.text.trim();
                                    final desc = descController.text.trim();
                                    final price = priceController.text.trim();

                                    String? imgBase64;
                                    if (selectedImage != null) {
                                      try {
                                        final bytes = await File(selectedImage!.path).readAsBytes();
                                        imgBase64 = 'data:image/png;base64,' + base64Encode(bytes);
                                      } catch (e) {
                                        debugPrint('Error reading picked image file: $e');
                                      }
                                    }

                                    final result = await DatabaseService().proposePlace(
                                      name: name,
                                      address: address,
                                      categoryId: selectedCategoryId!,
                                      description: desc,
                                      price: price,
                                      image: imgBase64,
                                      latitude: selectedLatLng?.latitude,
                                      longitude: selectedLatLng?.longitude,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (result != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đề xuất thành công! Vui lòng đợi Admin duyệt.'),
                                            backgroundColor: AppTheme.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Gửi đề xuất thất bại. Vui lòng thử lại.'),
                                            backgroundColor: AppTheme.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Gửi đề xuất ngay',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected ? AppTheme.primaryGradient : null,
        color: isSelected ? null : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppTheme.border,
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.bodyText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _displayPlaces;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _loadPlaces(page: 1),
            color: AppTheme.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
              // ── Header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar & Propose button & Filter
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withAlpha(10),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(color: AppTheme.darkText, fontSize: 13.5),
                                      decoration: const InputDecoration(
                                        hintText: 'Tìm địa điểm, quán...',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val;
                                        });
                                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                                        _debounce = Timer(const Duration(milliseconds: 500), () {
                                          _loadPlaces(page: 1);
                                        });
                                      },
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                                        _loadPlaces(page: 1);
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: AppTheme.subtitleText,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showFilterBottomSheet(context),
                            child: Container(
                              padding: const EdgeInsets.all(10.5),
                              decoration: BoxDecoration(
                                color: (_uiPriceLevels.isNotEmpty || _selectedMinRating > 0 || _selectedCategory != 'Nổi bật')
                                    ? AppTheme.primary
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (_uiPriceLevels.isNotEmpty || _selectedMinRating > 0 || _selectedCategory != 'Nổi bật')
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withAlpha(10),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: (_uiPriceLevels.isNotEmpty || _selectedMinRating > 0 || _selectedCategory != 'Nổi bật')
                                    ? Colors.white
                                    : AppTheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showProposePlaceSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_location_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đề xuất',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    
                    // Filter chips (Categories)
                    _isLoadingCategories
                        ? const SizedBox(
                            height: 36,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 36,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length + 1,
                              itemBuilder: (context, index) {
                                final label = index == 0 ? 'Nổi bật' : _categories[index - 1]['name'] ?? '';
                                final isSelected = _selectedCategory == label;
                                return GestureDetector(
                                  onTap: () {
                                    if (_selectedCategory != label) {
                                      setState(() {
                                        _selectedCategory = label;
                                      });
                                      _loadPlaces(page: 1);
                                    }
                                  },
                                  child: _filterChip(label, isSelected),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Places List ──────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (displayList.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off_rounded, size: 48, color: AppTheme.subtitleText),
                      const SizedBox(height: 12),
                      Text(
                        'Không tìm thấy địa điểm nào',
                        style: TextStyle(
                          color: AppTheme.subtitleText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == displayList.length) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _currentPage > 1
                                      ? AppTheme.primary.withAlpha(80)
                                      : AppTheme.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                minimumSize: Size.zero,
                              ),
                              onPressed: _currentPage > 1 && !_isLoading
                                  ? () {
                                      _loadPlaces(page: _currentPage - 1);
                                      _scrollController.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  : null,
                              child: Icon(
                                Icons.arrow_back_ios_rounded,
                                size: 14,
                                color: _currentPage > 1 ? AppTheme.primary : AppTheme.subtitleText,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              'Trang $_currentPage',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                                fontFamily: 'SDK_SC_Web-Heavy',
                              ),
                            ),
                            const SizedBox(width: 20),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _hasMore
                                      ? AppTheme.primary.withAlpha(80)
                                      : AppTheme.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                minimumSize: Size.zero,
                              ),
                              onPressed: _hasMore && !_isLoading
                                  ? () {
                                      _loadPlaces(page: _currentPage + 1);
                                      _scrollController.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  : null,
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: _hasMore ? AppTheme.primary : AppTheme.subtitleText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (index > displayList.length) return null;
                    final place = displayList[index];
                    final addressText = StringUtils.cleanAddress(place['address'] ?? '');
                    final priceText = place['price'] ?? 'Liên hệ';
                    final double? rawRating = (place['rating'] as num?)?.toDouble();
                    final ratingVal = rawRating ?? 0.0;
                    final ratingText = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : 'Mới';
                    final tagText = place['category']?['name'] ?? 'Địa điểm';

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: GestureDetector(
                        onTap: () => PlaceDetailBottomSheet.show(context, place),
                        child: Container(
                          decoration: AppTheme.premiumCardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                    child: (place['image'] != null && place['image'].toString().isNotEmpty)
                                        ? (place['image'].toString().startsWith('data:image/') && place['image'].toString().contains('base64,'))
                                            ? Image.memory(
                                                base64Decode(place['image'].toString().split('base64,').last),
                                                height: 185,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) => Container(
                                                  height: 185,
                                                  width: double.infinity,
                                                  decoration: const BoxDecoration(
                                                    gradient: AppTheme.primaryGradient,
                                                    borderRadius: BorderRadius.vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.location_on_rounded,
                                                    color: Colors.white54,
                                                    size: 48,
                                                  ),
                                                ),
                                              )
                                            : Image.network(
                                                place['image'],
                                                height: 185,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) => Container(
                                                  height: 185,
                                                  width: double.infinity,
                                                  decoration: const BoxDecoration(
                                                    gradient: AppTheme.primaryGradient,
                                                    borderRadius: BorderRadius.vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.location_on_rounded,
                                                    color: Colors.white54,
                                                    size: 48,
                                                  ),
                                                ),
                                              )
                                        : Container(
                                            height: 185,
                                            width: double.infinity,
                                            decoration: const BoxDecoration(
                                              gradient: AppTheme.primaryGradient,
                                              borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(20),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              color: Colors.white54,
                                              size: 48,
                                            ),
                                          ),
                                  ),
                                  // Gradient overlay
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: 70,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withAlpha(100),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Tag (Category)
                                  Positioned(
                                    top: 14,
                                    left: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tagText,
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Rating
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(140),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: AppTheme.amber,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            ratingText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.darkText,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: AppTheme.subtitleText,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            addressText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.subtitleText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    // Price row
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Chi phí tham khảo',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.subtitleText,
                                              ),
                                            ),
                                            Text(
                                              priceText,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primary,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Actions row
                                    SizedBox(
                                      width: double.infinity,
                                      child: GestureDetector(
                                        onTap: () => PlaceDetailBottomSheet.show(context, place),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF2563EB).withAlpha(51),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Xem chi tiết',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ],
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
                      ),
                    );
                  },
                  childCount: displayList.length + 1,
                ),
              ),
            // Bottom padding for floating nav
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    ),
  ),
  );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bộ lọc tìm kiếm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _uiPriceLevels.clear();
                            _selectedMinRating = 0.0;
                            _selectedCategory = 'Nổi bật';
                          });
                        },
                        child: const Text(
                          'Xóa tất cả',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 20),
                  const SizedBox(height: 8),

                  // Mức giá
                  const Text(
                    'Mức giá',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterSheetChip(
                        label: 'Giá rẻ',
                        isSelected: _uiPriceLevels.contains('cheap'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiPriceLevels.contains('cheap')) {
                              _uiPriceLevels.remove('cheap');
                            } else {
                              _uiPriceLevels.add('cheap');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: 'Trung bình',
                        isSelected: _uiPriceLevels.contains('moderate'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiPriceLevels.contains('moderate')) {
                              _uiPriceLevels.remove('moderate');
                            } else {
                              _uiPriceLevels.add('moderate');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: 'Sang trọng',
                        isSelected: _uiPriceLevels.contains('expensive'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiPriceLevels.contains('expensive')) {
                              _uiPriceLevels.remove('expensive');
                            } else {
                              _uiPriceLevels.add('expensive');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Đánh giá
                  const Text(
                    'Đánh giá (Tối thiểu)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterSheetChip(
                        label: 'Tất cả',
                        isSelected: _selectedMinRating == 0.0,
                        onTap: () {
                          setSheetState(() {
                            _selectedMinRating = 0.0;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: '3★+',
                        isSelected: _selectedMinRating == 3.0,
                        onTap: () {
                          setSheetState(() {
                            _selectedMinRating = 3.0;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: '4★+',
                        isSelected: _selectedMinRating == 4.0,
                        onTap: () {
                          setSheetState(() {
                            _selectedMinRating = 4.0;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: '4.5★+',
                        isSelected: _selectedMinRating == 4.5,
                        onTap: () {
                          setSheetState(() {
                            _selectedMinRating = 4.5;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Danh mục từ database
                  const Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCategoryFilterChip(
                        label: 'Nổi bật',
                        isSelected: _selectedCategory == 'Nổi bật',
                        onTap: () {
                          setSheetState(() {
                            _selectedCategory = 'Nổi bật';
                          });
                        },
                      ),
                      ..._categories.map((cat) {
                        final catName = cat['name']?.toString() ?? '';
                        if (catName.isEmpty) return const SizedBox.shrink();
                        final isSelected = _selectedCategory == catName;
                        return _buildCategoryFilterChip(
                          label: catName,
                          isSelected: isSelected,
                          onTap: () {
                            setSheetState(() {
                              _selectedCategory = catName;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Apply button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {});
                      _loadPlaces(page: 1);
                    },
                    child: Container(
                      height: 50,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Áp dụng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSheetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
