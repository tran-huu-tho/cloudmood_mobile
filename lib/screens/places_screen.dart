import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/place_detail_bottom_sheet.dart';

class CloudmoodPlacesScreen extends StatefulWidget {
  const CloudmoodPlacesScreen({super.key});

  @override
  State<CloudmoodPlacesScreen> createState() => _CloudmoodPlacesScreenState();
}

class _CloudmoodPlacesScreenState extends State<CloudmoodPlacesScreen> {
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingCategories = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadPlaces();
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

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all approved places
      final fetched = await DatabaseService().fetchPlaces();
      setState(() {
        _places = fetched;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading places: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _displayPlaces {
    return _places.where((place) {
      // Filter by category
      if (_selectedCategory != 'Tất cả') {
        final cat = place['category'];
        final catName = cat != null ? cat['name'] : '';
        if (catName != _selectedCategory) {
          return false;
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final name = (place['name'] ?? '').toString().toLowerCase();
        final address = (place['address'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !address.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
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
    final imageController = TextEditingController();
    
    int? selectedCategoryId;
    if (_categories.isNotEmpty) {
      selectedCategoryId = int.tryParse(_categories.first['id'].toString());
    }

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
                              style: TextStyle(
                                fontSize: 18,
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
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtitleText,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Place name
                        Text('Tên địa điểm *', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          style: TextStyle(color: AppTheme.darkText),
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
                        Text('Địa chỉ *', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: addressController,
                          style: TextStyle(color: AppTheme.darkText),
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
                        Text('Danh mục *', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          dropdownColor: AppTheme.surface,
                          style: TextStyle(color: AppTheme.darkText, fontSize: 14),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'Chọn danh mục',
                            prefixIcon: Icons.category_rounded,
                          ),
                          items: _categories.map((cat) {
                            final id = int.parse(cat['id'].toString());
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(cat['name'] ?? ''),
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
                        Text('Mô tả *', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descController,
                          style: TextStyle(color: AppTheme.darkText),
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
                        Text('Giá tham khảo *', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: priceController,
                          style: TextStyle(color: AppTheme.darkText),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'VD: Miễn phí hoặc 50.000đ - 100.000đ',
                            prefixIcon: Icons.attach_money_rounded,
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty)
                              ? 'Vui lòng nhập giá tham khảo'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Image URL
                        Text('Đường dẫn ảnh (URL)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: imageController,
                          style: TextStyle(color: AppTheme.darkText),
                          decoration: AppTheme.inputDecoration(
                            hintText: 'https://images.unsplash.com/... (tùy chọn)',
                            prefixIcon: Icons.image_rounded,
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
                                    final img = imageController.text.trim();

                                    final result = await DatabaseService().proposePlace(
                                      name: name,
                                      address: address,
                                      categoryId: selectedCategoryId!,
                                      description: desc,
                                      price: price,
                                      image: img.isNotEmpty ? img : null,
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProposePlaceSheet(context),
        backgroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
                    const SizedBox(height: 16),
                    // Search bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
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
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: AppTheme.darkText),
                              decoration: const InputDecoration(
                                hintText: 'Tìm địa điểm, nhà hàng, quán cà phê...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
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
                                final label = index == 0 ? 'Tất cả' : _categories[index - 1]['name'] ?? '';
                                final isSelected = _selectedCategory == label;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = label;
                                    });
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
                    if (index >= displayList.length) return null;
                    final place = displayList[index];
                    final placeId = int.tryParse(place['id'].toString()) ?? 1;
                    final addressText = place['address'] ?? '';
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
                                    child: Image.network(
                                      place['image'] ?? '',
                                      height: 185,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        height: 185,
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
                  childCount: displayList.length,
                ),
              ),
            // Bottom padding for floating nav
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
