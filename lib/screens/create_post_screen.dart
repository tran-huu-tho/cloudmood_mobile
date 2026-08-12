import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../widgets/upload_progress_dialog.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedFiles = [];
  
  // Tagged Place state
  Map<String, dynamic>? _taggedPlace;
  bool _isSearchingPlaces = false;
  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _placeSearchController = TextEditingController();

  bool _isUploading = false;

  @override
  void dispose() {
    _contentController.dispose();
    _placeSearchController.dispose();
    super.dispose();
  }

  // 1. Chọn nhiều ảnh
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 800,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  // 2. Chọn video
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (video != null) {
        setState(() {
          _selectedFiles.add(video);
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  // 3. Tìm kiếm địa điểm
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearchingPlaces = true;
    });

    try {
      final response = await ApiClient.get('/places', query: {
        'query': query,
        'limit': '5',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _searchResults = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _isSearchingPlaces = false;
        });
      } else {
        setState(() {
          _isSearchingPlaces = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      setState(() {
        _isSearchingPlaces = false;
      });
    }
  }

  // 4. Gửi bài viết (Multipart Request)
  Future<void> _submitPost() async {
    if (_isUploading) return; // Ngăn chặn gửi trùng lặp do bấm nhanh nhiều lần

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng viết nội dung bài đăng')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Đang tải lên bài viết...');
    showUploadProgressDialog(context, progressNotifier: progressNotifier, statusNotifier: statusNotifier);

    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/forum');
      final request = ProgressMultipartRequest(
        'POST',
        uri,
        onProgress: (bytes, total) {
          if (total > 0) {
            final p = bytes / total;
            progressNotifier.value = p;
            if (p >= 0.99) {
              statusNotifier.value = 'Đang xử lý & lưu tệp...';
            }
          }
        },
      );

      // Thêm Authorization Header
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Thêm các trường dữ liệu
      request.fields['content'] = content;
      if (_taggedPlace != null) {
        request.fields['placeId'] = _taggedPlace!['id'].toString();
      }

      // Thêm tệp đính kèm
      for (var file in _selectedFiles) {
        final multipartFile = await http.MultipartFile.fromPath('media', file.path, filename: file.name);
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) Navigator.pop(context); // Close progress dialog

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng bài thành công!')),
          );
          Navigator.of(context).pop(true); // Trở về và báo cập nhật
        }
      } else {
        String errorMsg = 'Đăng bài thất bại. Vui lòng thử lại.';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng bài thất bại. Vui lòng thử lại.')),
        );
      }
    }
  }

  void _showPlaceSearchDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  const Text(
                    'Gắn thẻ địa điểm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _placeSearchController,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Nhập tên địa điểm...',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) async {
                              await _searchPlaces(val);
                              setDialogState(() {});
                            },
                          ),
                        ),
                        if (_placeSearchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _placeSearchController.clear();
                              _searchResults.clear();
                              setDialogState(() {});
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Results List
                  SizedBox(
                    height: 320,
                    child: _isSearchingPlaces
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                        : _searchResults.isEmpty
                            ? Center(
                                child: Text(
                                  _placeSearchController.text.isEmpty
                                      ? 'Nhập tên địa điểm để tìm kiếm'
                                      : 'Không tìm thấy địa điểm nào',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                                itemBuilder: (context, index) {
                                  final place = _searchResults[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      place['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    subtitle: Text(
                                      place['address'] ?? '',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _taggedPlace = place;
                                      });
                                      _placeSearchController.clear();
                                      _searchResults.clear();
                                      Navigator.of(context).pop();
                                    },
                                  );
                                },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Viết bài mới',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                  )
                : GestureDetector(
                    onTap: _submitPost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Đăng',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              90 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Text Field Content Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _contentController,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A), height: 1.4),
                    decoration: const InputDecoration(
                      hintText: 'Bạn đang nghĩ gì? Chia sẻ kinh nghiệm chuyến đi của bạn...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14.5),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Tagged Place Indicator Badge
                if (_taggedPlace != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _taggedPlace!['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _taggedPlace = null;
                            });
                          },
                          child: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF93C5FD)),
                        )
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 3. Media Grid View
                if (_selectedFiles.isNotEmpty) ...[
                  const Text(
                    'Tệp đã chọn:',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      final isVideo = file.path.endsWith('.mp4') || file.path.endsWith('.mov');
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isVideo
                                ? Container(
                                    color: Colors.black87,
                                    child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                                  )
                                : Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.black87,
                                        child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                                      );
                                    },
                                  ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(5),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          // 4. Attachments Toolbar (Bottom overlay)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  _buildAttachmentIconButton(
                    icon: Icons.photo_library_rounded,
                    onTap: _pickImages,
                  ),
                  const SizedBox(width: 10),
                  _buildAttachmentIconButton(
                    icon: Icons.videocam_rounded,
                    onTap: _pickVideo,
                  ),
                  const SizedBox(width: 10),
                  _buildAttachmentIconButton(
                    icon: Icons.location_on_rounded,
                    onTap: _showPlaceSearchDialog,
                  ),
                  const Spacer(),
                  const Text(
                    'Thêm vào bài đăng',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF2563EB),
          size: 22,
        ),
      ),
    );
  }
}
