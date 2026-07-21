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

class CloudmoodPlacesScreen extends StatefulWidget {
  const CloudmoodPlacesScreen({super.key});

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

  final List<String> _uiAmenities = []; // 'wifi', 'ac', 'parking', 'pool', 'breakfast', 'outdoor'

  List<String> get _dbAmenities {
    final List<String> dbAm = [];
    if (_uiAmenities.contains('wifi')) dbAm.add('Wifi miễn phí');
    if (_uiAmenities.contains('ac')) dbAm.add('Máy lạnh');
    if (_uiAmenities.contains('parking')) dbAm.add('đỗ xe');
    if (_uiAmenities.contains('pool')) dbAm.add('Hồ bơi');
    if (_uiAmenities.contains('breakfast')) dbAm.add('Ăn sáng');
    if (_uiAmenities.contains('outdoor')) dbAm.add('ngoài trời');
    return dbAm;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadPlaces(page: 1);
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
        amenities: _dbAmenities.isNotEmpty ? _dbAmenities : null,
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

  void _showWriteReviewDialog(
    BuildContext context,
    int placeId,
    String placeName,
  ) {
    final user = AuthService().currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để gửi đánh giá!'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    double selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.lightAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: AppTheme.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đánh giá $placeName',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn số sao:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.subtitleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      final isSelected = starVal <= selectedRating;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedRating = starVal.toDouble();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppTheme.amber,
                            size: 34,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: TextStyle(color: AppTheme.darkText),
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Chia sẻ cảm nhận của bạn...',
                      prefixIcon: Icons.rate_review_rounded,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Hủy',
                    style: TextStyle(color: AppTheme.subtitleText),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () async {
                    final comment = commentController.text.trim();
                    if (comment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập bình luận!'),
                        ),
                      );
                      return;
                    }

                    final result = await DatabaseService().createPlaceReview(
                      userId: user.id,
                      placeId: placeId,
                      rating: selectedRating,
                      comment: comment,
                      authorName: user.fullName,
                      authorAvatar: user.avatar ?? '',
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (result != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi đánh giá thành công!'),
                            backgroundColor: AppTheme.green,
                          ),
                        );
                        _loadPlaces(); // Reload to refresh rating
                      }
                    }
                  },
                  child: const Text('Gửi đánh giá'),
                ),
              ],
            );
          },
        );
      },
    );
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
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đề xuất địa điểm mới',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: AppTheme.subtitleText),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Địa điểm của bạn sẽ được gửi tới Admin phê duyệt trước khi xuất hiện.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.subtitleText,
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
                                  side: BorderSide(color: AppTheme.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text('Hủy', style: TextStyle(color: AppTheme.subtitleText)),
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
                                ),
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
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
                                child: const Text('Gửi đề xuất'),
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
                      Text(
                        'KHÁM PHÁ CÁC ĐỊA ĐIỂM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Địa điểm thú vị',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkText,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showProposePlaceSheet(context),
                            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                            label: const Text(
                              'Đề xuất mới',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              backgroundColor: AppTheme.primaryContainer,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    // Search bar & Filter
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(18),
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
                                    style: TextStyle(color: AppTheme.darkText),
                                    decoration: const InputDecoration(
                                      hintText: 'Tìm địa điểm, nhà hàng, quán cà phê...',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
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
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _showFilterBottomSheet(context),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_uiPriceLevels.isNotEmpty || _selectedMinRating > 0 || _uiAmenities.isNotEmpty)
                                  ? AppTheme.primary
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (_uiPriceLevels.isNotEmpty || _selectedMinRating > 0 || _uiAmenities.isNotEmpty)
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
                              color: (_uiPriceLevels.isNotEmpty || _selectedMinRating > 0 || _uiAmenities.isNotEmpty)
                                  ? Colors.white
                                  : AppTheme.primary,
                              size: 22,
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
                                side: BorderSide(color: AppTheme.border),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back_ios_rounded, size: 12, color: _currentPage > 1 ? AppTheme.primary : AppTheme.subtitleText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Trang trước',
                                    style: TextStyle(
                                      color: _currentPage > 1 ? AppTheme.primary : AppTheme.subtitleText,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'SDK_SC_Web-Heavy',
                                    ),
                                  ),
                                ],
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
                                side: BorderSide(color: AppTheme.border),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Trang sau',
                                    style: TextStyle(
                                      color: _hasMore ? AppTheme.primary : AppTheme.subtitleText,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'SDK_SC_Web-Heavy',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _hasMore ? AppTheme.primary : AppTheme.subtitleText),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (index > displayList.length) return null;
                    final place = displayList[index];
                    final placeId = int.tryParse(place['id'].toString()) ?? 1;
                    final addressText = StringUtils.cleanAddress(place['address'] ?? '');
                    final priceText = place['price'] ?? 'Liên hệ';
                    final ratingVal = (place['rating'] as num?)?.toDouble() ?? 5.0;
                    final ratingText = ratingVal.toStringAsFixed(1);
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: BorderSide(
                                              color: AppTheme.border,
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: () => _showWriteReviewDialog(
                                            context,
                                            placeId,
                                            place['name'] ?? 'Địa điểm',
                                          ),
                                          child: const Text(
                                            'Đánh giá',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () => PlaceDetailBottomSheet.show(context, place),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: AppTheme.gradientButtonDecoration(
                                              radius: 12,
                                            ),
                                            child: const Text(
                                              'Xem chi tiết',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bộ lọc tìm kiếm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkText,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _uiPriceLevels.clear();
                            _selectedMinRating = 0.0;
                            _uiAmenities.clear();
                          });
                        },
                        child: const Text(
                          'Xóa tất cả',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: AppTheme.border),
                  const SizedBox(height: 16),
                  Text(
                    'Mức giá',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
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
                  const SizedBox(height: 24),
                  Text(
                    'Đánh giá (Tối thiểu)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
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
                  const SizedBox(height: 24),
                  Text(
                    'Tiện ích',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterSheetChip(
                        label: 'Wifi',
                        isSelected: _uiAmenities.contains('wifi'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiAmenities.contains('wifi')) {
                              _uiAmenities.remove('wifi');
                            } else {
                              _uiAmenities.add('wifi');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: 'Máy lạnh',
                        isSelected: _uiAmenities.contains('ac'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiAmenities.contains('ac')) {
                              _uiAmenities.remove('ac');
                            } else {
                              _uiAmenities.add('ac');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: 'Đỗ xe',
                        isSelected: _uiAmenities.contains('parking'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiAmenities.contains('parking')) {
                              _uiAmenities.remove('parking');
                            } else {
                              _uiAmenities.add('parking');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterSheetChip(
                        label: 'Hồ bơi',
                        isSelected: _uiAmenities.contains('pool'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiAmenities.contains('pool')) {
                              _uiAmenities.remove('pool');
                            } else {
                              _uiAmenities.add('pool');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: 'Ăn sáng',
                        isSelected: _uiAmenities.contains('breakfast'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiAmenities.contains('breakfast')) {
                              _uiAmenities.remove('breakfast');
                            } else {
                              _uiAmenities.add('breakfast');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSheetChip(
                        label: 'Ngoài trời',
                        isSelected: _uiAmenities.contains('outdoor'),
                        onTap: () {
                          setSheetState(() {
                            if (_uiAmenities.contains('outdoor')) {
                              _uiAmenities.remove('outdoor');
                            } else {
                              _uiAmenities.add('outdoor');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadPlaces(page: 1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        shadowColor: AppTheme.primary.withAlpha(80),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primary : AppTheme.darkText,
            ),
          ),
        ),
      ),
    );
  }
}
