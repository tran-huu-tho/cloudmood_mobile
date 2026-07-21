import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

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

    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/forum');
      final request = http.MultipartRequest('POST', uri);

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
        final multipartFile = await http.MultipartFile.fromPath('media', file.path);
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng bài thành công!')),
          );
          Navigator.of(context).pop(true); // Trở về và báo cập nhật
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
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
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Gắn thẻ địa điểm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _placeSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tên địa điểm...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) async {
                        await _searchPlaces(val);
                        setDialogState(() {}); // Cập nhật danh sách trong dialog
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_isSearchingPlaces)
                      const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    else if (_searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('Không tìm thấy địa điểm nào', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.place_rounded, color: AppTheme.primary),
                              title: Text(place['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(place['address'] ?? '', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        title: Text('Viết bài mới', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.darkText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _isUploading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary))
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                    ),
                    child: const Text('Đăng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Text Field Content
                TextField(
                  controller: _contentController,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Bạn đang nghĩ gì? Chia sẻ kinh nghiệm chuyến đi của bạn...',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Tagged Place Indicator
                if (_taggedPlace != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _taggedPlace!['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _taggedPlace = null;
                            });
                          },
                          child: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                        )
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 3. Media Grid View
                if (_selectedFiles.isNotEmpty) ...[
                  const Text('Tệp đã chọn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
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
                            borderRadius: BorderRadius.circular(8),
                            child: isVideo
                                ? Container(
                                    color: Colors.black87,
                                    child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                                  )
                                : Image.file(File(file.path), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(4),
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

          // 4. Attachments Toolbar (bottom sheet overlay style)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primary, size: 28),
                    onPressed: _pickImages,
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_rounded, color: AppTheme.primary, size: 28),
                    onPressed: _pickVideo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.pin_drop_rounded, color: AppTheme.primary, size: 28),
                    onPressed: _showPlaceSearchDialog,
                  ),
                  const Spacer(),
                  const Text('Thêm vào bài đăng', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
