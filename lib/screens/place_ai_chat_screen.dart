import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import '../widgets/save_to_trip_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class PlaceAIChatScreen extends StatefulWidget {
  final String placeName;
  final Map<String, dynamic>? placeInfo;

  const PlaceAIChatScreen({super.key, required this.placeName, this.placeInfo});

  @override
  State<PlaceAIChatScreen> createState() => _PlaceAIChatScreenState();
}

class _PlaceAIChatScreenState extends State<PlaceAIChatScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _sessionId;
  String _currentTitle = 'Cuộc trò chuyện mới';
  bool _isLoading = false;
  bool _isChatHidden = false;
  int _savedCount = 0;
  String _streamingText = '';
  bool _isStreaming = false;

  bool _isFullScreen = true;
  bool _isDragging = false;
  double? _dragHeight;
  LatLng? _mapCenter;

  // Dynamic suggestions from API
  List<String> _suggestions = [];
  bool _suggestionsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMapData();
    _loadChatSessions();
    _fetchSavedCount();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await AiService.getSuggestions(
      placeName: widget.placeName,
      type: 'place',
    );
    if (mounted) {
      setState(() {
      _suggestions = suggestions.isNotEmpty ? suggestions : [
        'Giờ mở cửa ở đây thế nào?',
        'Chi phí tham quan ở đây là bao nhiêu?',
        'Mọi người đánh giá nơi này thế nào?',
        'Nên dành bao lâu để tham quan ở đây?',
        'Có lưu ý hay mẹo gì khi ghé thăm không?',
        'Xung quanh đây có gì đáng tham quan?',
      ];
        _suggestionsLoading = false;
      });
    }
  }

  Future<void> _fetchSavedCount() async {
    final user = AuthService().currentUser.value;
    if (user != null && widget.placeInfo != null) {
      final trips = await DatabaseService().fetchUserItineraries(
        int.parse(user.id.toString()),
        isGuide: false,
      );
      if (mounted) {
        int tripsCount = 0;
        final targetId = widget.placeInfo!['id'];

        for (var trip in trips) {
          bool foundInTrip = false;
          final savedPlaces = trip['savedPlaces'] as List? ?? [];
          final detailsList = trip['details'] as List? ?? [];

          for (var d in savedPlaces) {
            if ((d['placeId'] ?? d['place']?['id']) == targetId &&
                (d['section'] != null && d['section'].toString().isNotEmpty)) {
              foundInTrip = true;
              break;
            }
          }
          if (!foundInTrip) {
            for (var d in detailsList) {
              if ((d['placeId'] ?? d['place']?['id']) == targetId &&
                  d['day'] != null) {
                foundInTrip = true;
                break;
              }
            }
          }
          if (foundInTrip) {
            tripsCount++;
          }
        }

        setState(() {
          _savedCount = tripsCount;
        });
      }
    }
  }

  Future<void> _loadChatSessions() async {
    final sessions = await AiService.getChatSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
      });
    }
  }

  Future<void> _loadChatHistory(String sessionId, String title) async {
    setState(() {
      _isLoading = true;
      _sessionId = sessionId;
      _currentTitle = title;
      _messages.clear();
    });

    final history = await AiService.getChatMessages(sessionId);

    if (mounted) {
      setState(() {
        _messages = history;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _startNewConversation() {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _currentTitle = 'Cuộc trò chuyện mới';
    });
  }

  void _showHistorySheet() {
    _loadChatSessions(); // Refresh list before showing
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lịch sử trò chuyện',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2FF),
                    child: Icon(Icons.add_comment, color: Color(0xFF4F46E5)),
                  ),
                  title: const Text(
                    'Tạo cuộc trò chuyện mới',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startNewConversation();
                  },
                ),
                const Divider(),
                Expanded(
                  child: _sessions.isEmpty
                      ? const Center(child: Text('Chưa có cuộc trò chuyện nào'))
                      : ListView.builder(
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            final isSelected = session.id == _sessionId;
                            return ListTile(
                              leading: Icon(
                                Icons.chat_bubble_outline,
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.grey,
                              ),
                              title: Text(
                                session.title.isNotEmpty
                                    ? session.title
                                    : 'Cuộc trò chuyện',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.darkText,
                                ),
                              ),
                              subtitle: Text(
                                '${session.updatedAt.day}/${session.updatedAt.month}/${session.updatedAt.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _loadChatHistory(session.id, session.title);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchMapData() async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(widget.placeName)}&format=json&limit=1',
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'CloudMoodApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat'].toString());
          final double lon = double.parse(data[0]['lon'].toString());
          if (mounted) {
            setState(() {
              _mapCenter = LatLng(lat, lon);
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _mapCenter = const LatLng(16.047079, 108.206230);
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _mapCenter = const LatLng(16.047079, 108.206230);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching map: $e');
      if (mounted) {
        setState(() {
          _mapCenter = const LatLng(16.047079, 108.206230);
        });
      }
    }
  }

  Future<void> _sendMessage([String? optionalText]) async {
    final text = (optionalText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: _sessionId ?? '',
          role: 'USER',
          content: text,
          createdAt: DateTime.now(),
        ),
      );
      _isLoading = true;
      _streamingText = '';
      _isStreaming = true;
    });

    _scrollToBottom();

    try {
      // Try streaming first
      StreamSubscription? subscription;
      bool gotSession = false;

      subscription =
          AiService.streamChat(
            sessionId: _sessionId,
            destination: widget.placeName,
            message: text,
          ).listen(
            (event) {
              if (!mounted) return;
              final type = event['type'];

              if (type == 'session' && !gotSession) {
                gotSession = true;
                setState(() {
                  _sessionId = event['sessionId'];
                });
                _loadChatSessions().then((_) {
                  if (_currentTitle == 'Cuộc trò chuyện mới' &&
                      _sessions.isNotEmpty) {
                    final currentSession = _sessions.firstWhere(
                      (s) => s.id == _sessionId,
                      orElse: () => _sessions.first,
                    );
                    setState(() => _currentTitle = currentSession.title);
                  }
                });
              } else if (type == 'token') {
                setState(() {
                  _streamingText += event['content'] ?? '';
                });
                _scrollToBottom();
              } else if (type == 'done') {
                setState(() {
                  _messages.add(
                    ChatMessage(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      sessionId: _sessionId!,
                      role: 'AI',
                      content: _streamingText,
                      createdAt: DateTime.now(),
                    ),
                  );
                  _streamingText = '';
                  _isStreaming = false;
                  _isLoading = false;
                });
                _scrollToBottom();
              } else if (type == 'error') {
                setState(() {
                  _streamingText = '';
                  _isStreaming = false;
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lỗi khi gửi tin nhắn')),
                );
              }
            },
            onError: (e) async {
              // Fallback to non-streaming
              try {
                final result = await AiService.sendChatMessage(
                  sessionId: _sessionId,
                  destination: widget.placeName,
                  message: text,
                );
                if (mounted) {
                  setState(() {
                    _sessionId = result['sessionId'];
                    _messages.add(
                      ChatMessage(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        sessionId: _sessionId!,
                        role: 'AI',
                        content: result['reply'],
                        createdAt: DateTime.now(),
                      ),
                    );
                    _streamingText = '';
                    _isStreaming = false;
                    _isLoading = false;
                  });
                  _scrollToBottom();
                  _loadChatSessions();
                }
              } catch (_) {
                if (mounted) {
                  setState(() {
                    _streamingText = '';
                    _isStreaming = false;
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lỗi khi gửi tin nhắn')),
                  );
                }
              }
            },
            onDone: () {
              // Streaming finished, ensure we're in clean state
              if (mounted && _isStreaming) {
                setState(() {
                  if (_streamingText.isNotEmpty) {
                    _messages.add(
                      ChatMessage(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        sessionId: _sessionId ?? '',
                        role: 'AI',
                        content: _streamingText,
                        createdAt: DateTime.now(),
                      ),
                    );
                  }
                  _streamingText = '';
                  _isStreaming = false;
                  _isLoading = false;
                });
                _scrollToBottom();
              }
            },
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _streamingText = '';
          _isStreaming = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi khi gửi tin nhắn')));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _selectedMapPlaceIndex = 0;
  final MapController _mapController = MapController();

  void _focusMapCamera() {
    final chatPlaces = _getAllChatPlaces();
    LatLng targetCenter = _mapCenter ?? const LatLng(10.033, 105.787);
    double targetZoom = 14.5;

    if (chatPlaces.isNotEmpty) {
      final safeIndex = _selectedMapPlaceIndex < chatPlaces.length ? _selectedMapPlaceIndex : 0;
      final cp = chatPlaces[safeIndex];
      if (cp['latitude'] != null && cp['longitude'] != null) {
        targetCenter = LatLng((cp['latitude'] as num).toDouble(), (cp['longitude'] as num).toDouble());
        targetZoom = 15.5;
      }
    } else if (widget.placeInfo != null && widget.placeInfo!['latitude'] != null && widget.placeInfo!['longitude'] != null) {
      targetCenter = LatLng(
        (widget.placeInfo!['latitude'] as num).toDouble(),
        (widget.placeInfo!['longitude'] as num).toDouble(),
      );
      targetZoom = 15.0;
    } else if (_mapCenter != null) {
      targetCenter = _mapCenter!;
      targetZoom = 13.5;
    }

    try {
      _mapController.move(targetCenter, targetZoom);
    } catch (_) {}
  }

  List<Map<String, dynamic>> _getAllChatPlaces() {
    final places = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final msg in _messages) {
      if (msg.role == 'AI') {
        final lines = msg.content.split('\n');
        for (final line in lines) {
          final item = _tryExtractPlaceItem(line);
          if (item != null) {
            final name = item['name']!;
            if (!seen.contains(name)) {
              seen.add(name);
              final dbPlace = _placeDbCache[name];
              places.add(dbPlace ?? {
                'name': name,
                'description': item['desc'],
                'image': _getPlaceImage(name),
                'rating': 4.5,
              });
            }
          }
        }
      }
    }
    return places;
  }

  final Map<String, Map<String, dynamic>> _placeDbCache = {};
  final Set<String> _loadingPlaceNames = {};

  void _fetchPlaceFromDb(String placeName) {
    if (_placeDbCache.containsKey(placeName) || _loadingPlaceNames.contains(placeName)) return;

    _loadingPlaceNames.add(placeName);
    DatabaseService().searchPlaces(
      destination: '',
      query: placeName,
    ).then((results) {
      if (results.isNotEmpty) {
        final matched = results.firstWhere(
          (p) {
            final n1 = p['name'].toString().toLowerCase();
            final n2 = placeName.toLowerCase();
            return n1.contains(n2) || n2.contains(n1);
          },
          orElse: () => results.first,
        );
        if (mounted) {
          setState(() {
            _placeDbCache[placeName] = matched;
          });
        }
      }
    }).catchError((e) {
      debugPrint('Error fetching DB place: $e');
    }).whenComplete(() {
      _loadingPlaceNames.remove(placeName);
    });
  }

  bool _isPlaceName(String text) {
    final clean = text.trim();
    if (clean.length < 2 || clean.length > 55) return false;

    final lower = clean.toLowerCase();

    const nonPlaceKeywords = [
      'thư giãn', 'đón hoàng hôn', 'thưởng thức', 'ngắm', 'chụp ảnh', 'check-in',
      'tận hưởng', 'trải nghiệm', 'dạo bộ', 'hóng gió', 'mua sắm', 'ăn sáng',
      'ăn trưa', 'ăn tối', 'uống trà', 'đi dạo', 'tham quan', 'khám phá',
      'tìm hiểu', 'theo thông tin chung', 'lưu ý', 'tổng quan', 'gợi ý',
      'lịch trình', 'ghi chú', 'mẹo', 'đánh giá', 'giá vé', 'giờ mở cửa',
      'địa chỉ', 'hướng dẫn', 'kinh nghiệm', 'tóm tắt', 'kết luận',
      'lưu ý quan trọng', 'nổi bật', 'đặc sắc', 'ưu điểm', 'nhược điểm',
      'phù hợp với', 'thời điểm lý tưởng', 'phương tiện di chuyển',
      'chi phí tham khảo', 'thông tin chi tiết', 'mô tả', 'hình ảnh',
      'trang phục', 'chuẩn bị', 'đêm nhạc', 'không gian', 'thời tiết',
      'danh mục', 'cảnh báo', 'ăn uống', 'hành lý', 'an toàn', 'bảo quản',
      'đặt phòng', 'đặt vé', 'điểm nổi bật', 'thời điểm', 'thời gian',
      'ngân sách', 'thành viên', 'nhịp độ', 'khoảng thời gian', 'bao lâu'
    ];

    for (final item in nonPlaceKeywords) {
      if (lower.contains(item)) return false;
    }

    if (RegExp(r'^(ngày\s*\d+|buổi\s*(sáng|trưa|chiều|tối)|bước\s*\d+)', caseSensitive: false).hasMatch(clean)) {
      return false;
    }

    if (RegExp(r'^\d+$').hasMatch(clean)) return false;

    if (_placeDbCache.containsKey(clean)) return true;

    const placeKeywords = [
      'chợ', 'công viên', 'cầu', 'bến', 'bãi', 'chùa', 'đền', 'miếu',
      'bảo tàng', 'quán', 'cà phê', 'coffee', 'khách sạn', 'hotel',
      'resort', 'nhà hàng', 'quảng trường', 'bán đảo', 'hồ', 'sông',
      'tháp', 'vườn', 'khu du lịch', 'trung tâm', 'phố', 'đường',
      'đảo', 'bãi biển', 'am', 'thiền viện', 'nhà thờ', 'thảo cầm viên',
      'gành', 'mũi', 'vịnh', 'đèo', 'suối', 'thác', 'động', 'hang', 'núi',
      'bãi bồi', 'homestay', 'bar', 'pub', 'billiards', 'bida', 'bún', 'phở',
      'ốc', 'lẩu', 'bánh', 'trà sữa', 'spa', 'massage', 'cinema', 'rạp'
    ];

    for (final kw in placeKeywords) {
      if (lower.contains(kw)) return true;
    }

    if (RegExp(r'^(thưởng thức|tham quan|đón|ngắm|thư giãn|chụp|check|ăn|uống|đi|đến|ghé|xem|mua|dạo|tận hưởng|trải nghiệm)\b', caseSensitive: false).hasMatch(lower)) {
      return false;
    }

    return false;
  }

  Map<String, String>? _tryExtractPlaceItem(String rawLine) {
    final cleanLine = rawLine.trim();
    if (cleanLine.isEmpty) return null;

    String content = cleanLine;
    if (content.startsWith('- ') || content.startsWith('* ')) {
      content = content.substring(2).trim();
    } else if (RegExp(r'^\d+\.\s').hasMatch(content)) {
      content = content.replaceFirst(RegExp(r'^\d+\.\s'), '').trim();
    }

    final boldMatch = RegExp(r'^\*\*(.+?)\*\*').firstMatch(content);
    if (boldMatch != null) {
      final placeName = boldMatch.group(1) ?? '';
      if (_isPlaceName(placeName)) {
        String desc = content.substring(boldMatch.end).trim();
        if (desc.startsWith(':') || desc.startsWith('-')) {
          desc = desc.substring(1).trim();
        }
        return {
          'name': placeName,
          'desc': desc,
        };
      }
    }
    return null;
  }

  String _getPlaceImage(String placeName) {
    final lower = placeName.toLowerCase();
    if (lower.contains('chợ') || lower.contains('market') || lower.contains('ẩm thực')) {
      return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=300&fit=crop';
    } else if (lower.contains('công viên') || lower.contains('park') || lower.contains('bờ sông') || lower.contains('bãi bồi')) {
      return 'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?w=300&fit=crop';
    } else if (lower.contains('cầu') || lower.contains('bridge') || lower.contains('bến') || lower.contains('thuyền')) {
      return 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=300&fit=crop';
    } else if (lower.contains('chùa') || lower.contains('đền') || lower.contains('miếu') || lower.contains('bảo tàng')) {
      return 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=300&fit=crop';
    } else if (lower.contains('cà phê') || lower.contains('coffee') || lower.contains('quán')) {
      return 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=300&fit=crop';
    } else if (lower.contains('khách sạn') || lower.contains('hotel') || lower.contains('resort')) {
      return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=300&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=300&fit=crop';
  }

  Widget _buildPlaceCardBlock(String placeName, String description) {
    _fetchPlaceFromDb(placeName);
    final dbPlace = _placeDbCache[placeName];

    String imageUrl = _getPlaceImage(placeName);
    String categoryName = '';
    String displayDesc = description;
    double rating = 4.5;
    int reviewCount = 120;

    if (dbPlace != null) {
      if (dbPlace['image'] != null && dbPlace['image'].toString().isNotEmpty) {
        final rawImg = dbPlace['image'].toString();
        imageUrl = rawImg.startsWith('/') ? '${ApiClient.baseUrl}$rawImg' : rawImg;
      } else if (dbPlace['photos'] != null && dbPlace['photos'] is List && (dbPlace['photos'] as List).isNotEmpty) {
        final p0 = dbPlace['photos'][0];
        if (p0 is Map) {
          final rawImg = (p0['urlOriginal'] ?? p0['urlThumbnail'] ?? p0['url'] ?? '').toString();
          if (rawImg.isNotEmpty) {
            imageUrl = rawImg.startsWith('/') ? '${ApiClient.baseUrl}$rawImg' : rawImg;
          }
        }
      }

      if (dbPlace['category'] != null && dbPlace['category']['name'] != null) {
        categoryName = dbPlace['category']['name'].toString();
      }
      if (dbPlace['description'] != null && dbPlace['description'].toString().isNotEmpty) {
        displayDesc = dbPlace['description'].toString();
      }
      if (dbPlace['rating'] != null) {
        rating = (dbPlace['rating'] as num).toDouble();
      }
      if (dbPlace['userRatingCount'] != null) {
        reviewCount = (dbPlace['userRatingCount'] as num).toInt();
      }
    }

    final placeData = dbPlace ?? {
      'name': placeName,
      'address': displayDesc,
      'image': imageUrl,
      'rating': rating,
      'user_ratings_total': reviewCount,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            PlaceDetailBottomSheet.show(
              context,
              placeData,
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (categoryName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '($categoryName)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                      if (displayDesc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          displayDesc,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.info_outline_rounded, size: 11, color: Color(0xFF64748B)),
                          SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'Chạm để xem chi tiết',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    SaveToTripBottomSheet.show(
                      context,
                      placeData,
                      onSaved: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã thêm "$placeName" vào chuyến đi!'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: Color(0xFF2563EB),
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Thêm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      );
    }

    // Simple markdown-like rendering for AI messages
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final placeItem = _tryExtractPlaceItem(line);
      if (placeItem != null) {
        widgets.add(_buildPlaceCardBlock(placeItem['name']!, placeItem['desc']!));
        continue;
      }

      // Headers
      if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(4),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              line.substring(3),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
          ),
        );
      }
      // Bullet points
      else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ')) {
        final indent = line.length - line.trimLeft().length;
        final text = line.trimLeft().substring(2);
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: indent > 0 ? 16.0 : 0,
              top: 2,
              bottom: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.darkText.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: _buildRichText(text, false)),
              ],
            ),
          ),
        );
      }
      // Numbered lists
      else if (RegExp(r'^\d+\.\s').hasMatch(line.trimLeft())) {
        final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line.trimLeft());
        if (match != null) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${match.group(1)}.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  Expanded(child: _buildRichText(match.group(2) ?? '', false)),
                ],
              ),
            ),
          );
        }
      }
      // Normal text
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 1),
            child: _buildRichText(line, false),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Renders bold text (**text**) within a line
  Widget _buildRichText(String text, bool isUser) {
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isUser ? Colors.white : AppTheme.darkText,
          fontSize: 15,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildStreamingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(
            16,
          ).copyWith(bottomLeft: const Radius.circular(0)),
          border: Border.all(color: AppTheme.border),
        ),
        child: _streamingText.isEmpty
            ? _buildTypingDots()
            : _buildMessageContent(_streamingText, false),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Color(0xFF4F46E5),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            _buildTypingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + i * 200),
          builder: (context, value, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(
                  alpha:
                      0.3 + 0.4 * (1 - (value - 0.5).abs() * 2).clamp(0.0, 1.0),
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16, color: AppTheme.subtitleText),
        ),
      ),
    );
  }

  Widget _buildChatBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        GestureDetector(
          onVerticalDragStart: (details) {
            setState(() {
              _isDragging = true;
              final screenHeight = MediaQuery.of(context).size.height;
              final topPadding = MediaQuery.of(context).padding.top;
              final headerHeight = topPadding + 56.0;
              _dragHeight = _isFullScreen
                  ? (screenHeight - headerHeight)
                  : 45.0;
            });
          },
          onVerticalDragUpdate: (details) {
            setState(() {
              final screenHeight = MediaQuery.of(context).size.height;
              final topPadding = MediaQuery.of(context).padding.top;
              final headerHeight = topPadding + 56.0;
              final max = screenHeight - headerHeight;
              final min = 45.0;

              _dragHeight = (_dragHeight ?? max) - details.primaryDelta!;
              if (_dragHeight! > max) _dragHeight = max;
              if (_dragHeight! < min) _dragHeight = min;
            });
          },
          onVerticalDragEnd: (details) {
            final screenHeight = MediaQuery.of(context).size.height;
            final topPadding = MediaQuery.of(context).padding.top;
            final headerHeight = topPadding + 56.0;
            final max = screenHeight - headerHeight;
            final min = 45.0;
            final mid = (max + min) / 2;

            setState(() {
              _isDragging = false;
              if (details.primaryVelocity != null &&
                  details.primaryVelocity!.abs() > 300) {
                _isFullScreen = details.primaryVelocity! < 0;
              } else {
                _isFullScreen = (_dragHeight ?? max) > mid;
              }
              _dragHeight = null;
            });
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight < 250) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_rounded,
                          color: AppTheme.subtitleText,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Thông tin từ Trợ lý AI có thể không hoàn toàn chính xác.',
                            style: TextStyle(
                              color: AppTheme.subtitleText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Stack(
                      children: [
                        if (_messages.isEmpty)
                          ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Có câu hỏi về ${widget.placeName} không?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkText,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ..._suggestions.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: () {
                                        _sendMessage(s);
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons
                                                  .subdirectory_arrow_right_rounded,
                                              color: Color(0xFF4F46E5),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                s,
                                                style: const TextStyle(
                                                  color: Color(0xFF4F46E5),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount:
                                _messages.length +
                                (_isStreaming ? 1 : 0) +
                                (_isLoading && !_isStreaming ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Streaming message (AI đang gõ)
                              if (_isStreaming && index == _messages.length) {
                                return _buildStreamingBubble();
                              }
                              // Loading indicator
                              if (index ==
                                  _messages.length + (_isStreaming ? 1 : 0)) {
                                return _buildTypingIndicator();
                              }
                              final msg = _messages[index];
                              final isUser = msg.role == 'USER';
                              return Column(
                                crossAxisAlignment: isUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? AppTheme.primary
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(16)
                                            .copyWith(
                                              bottomRight: isUser
                                                  ? const Radius.circular(0)
                                                  : const Radius.circular(16),
                                              bottomLeft: !isUser
                                                  ? const Radius.circular(0)
                                                  : const Radius.circular(16),
                                            ),
                                        border: isUser
                                            ? null
                                            : Border.all(
                                                color: AppTheme.border,
                                              ),
                                      ),
                                      child: _buildMessageContent(
                                        msg.content,
                                        isUser,
                                      ),
                                    ),
                                  ),
                                  // Action buttons for AI messages
                                  if (!isUser)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        left: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildActionButton(
                                            Icons.copy_rounded,
                                            'Sao chép',
                                            () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: msg.content,
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Đã sao chép'),
                                                  duration: Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          _buildActionButton(
                                            Icons.refresh_rounded,
                                            'Tạo lại',
                                            () {
                                              // Regenerate: resend the last user message
                                              if (_messages.length >= 2) {
                                                final lastUserMsg = _messages
                                                    .lastWhere(
                                                      (m) => m.role == 'USER',
                                                      orElse: () =>
                                                          _messages.last,
                                                    );
                                                _sendMessage(
                                                  lastUserMsg.content,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),
                        if (_isFullScreen)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: FloatingActionButton(
                              heroTag: 'ai_chat_map_btn_place',
                              onPressed: () {
                                final chatPlaces = _getAllChatPlaces();
                                setState(() {
                                  _isFullScreen = false;
                                  if (chatPlaces.isNotEmpty) {
                                    _isChatHidden = true;
                                    _selectedMapPlaceIndex = 0;
                                  }
                                });
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  _focusMapCamera();
                                });
                              },
                              backgroundColor: const Color(0xFF1E293B),
                              elevation: 4,
                              child: const Icon(
                                Icons.map_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Input Area
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Hỏi các câu hỏi liên quan đến du lịch',
                                    hintStyle: TextStyle(
                                      color: AppTheme.subtitleText,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: InkWell(
                                  onTap: () => _sendMessage(),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFA5B4FC),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 20,
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
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 56.0;
    final screenHeight = MediaQuery.of(context).size.height;

    final double defaultHeight = _isFullScreen
        ? (screenHeight - headerHeight)
        : 0.0;
    final double targetSheetHeight = (_isDragging && _dragHeight != null)
        ? _dragHeight!
        : defaultHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Positioned.fill(
            child: _mapCenter != null
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: () {
                        final chatPlaces = _getAllChatPlaces();
                        if (chatPlaces.isNotEmpty) {
                          final cp = chatPlaces.first;
                          if (cp['latitude'] != null && cp['longitude'] != null) {
                            return LatLng((cp['latitude'] as num).toDouble(), (cp['longitude'] as num).toDouble());
                          }
                        }
                        if (widget.placeInfo != null && widget.placeInfo!['latitude'] != null && widget.placeInfo!['longitude'] != null) {
                          return LatLng(
                            (widget.placeInfo!['latitude'] as num).toDouble(),
                            (widget.placeInfo!['longitude'] as num).toDouble(),
                          );
                        }
                        return _mapCenter ?? const LatLng(10.033, 105.787);
                      }(),
                      initialZoom: 14.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&apistyle=s.t%3A2%7Cp.v%3Aoff',
                      ),
                      MarkerLayer(
                        markers: () {
                          final chatPlaces = _getAllChatPlaces();
                          if (chatPlaces.isEmpty && _mapCenter != null) {
                            return [
                              Marker(
                                point: _mapCenter!,
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 38,
                                ),
                              ),
                            ];
                          }
                          return List.generate(chatPlaces.length, (idx) {
                            final cp = chatPlaces[idx];
                            final isSelected = idx == _selectedMapPlaceIndex;
                            double lat = _mapCenter?.latitude ?? 10.033;
                            double lon = _mapCenter?.longitude ?? 105.787;
                            if (cp['latitude'] != null && cp['longitude'] != null) {
                              lat = (cp['latitude'] as num).toDouble();
                              lon = (cp['longitude'] as num).toDouble();
                            } else {
                              lat += (idx % 3 - 1) * 0.007;
                              lon += (idx ~/ 3 - 1) * 0.007;
                            }
                            return Marker(
                              point: LatLng(lat, lon),
                              width: isSelected ? 54 : 44,
                              height: isSelected ? 54 : 44,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMapPlaceIndex = idx;
                                    _isChatHidden = true;
                                  });
                                  _focusMapCamera();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSelected ? 15 : 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          });
                        }(),
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
          ),

          if (_isChatHidden) _buildMapPlaceBottomSheet(),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: headerHeight,
            width: double.infinity,
            color: _isFullScreen ? Colors.white : Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: _isFullScreen ? Colors.transparent : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: _isFullScreen
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: AppTheme.darkText),
                      onPressed: () {
                        if (!_isFullScreen) {
                          setState(() {
                            _isFullScreen = true;
                            _isChatHidden = false;
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showHistorySheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: _isFullScreen ? 0 : 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isFullScreen
                            ? Colors.transparent
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isFullScreen
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _currentTitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.darkText,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            color: AppTheme.darkText.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: _isChatHidden ? 0 : targetSheetHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _isFullScreen
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  if (!_isFullScreen)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: _isFullScreen
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(20)),
                child: _isChatHidden
                    ? const SizedBox()
                    : SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: targetSheetHeight,
                          child: _buildChatBody(),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceBottomSheet() {
    final chatPlaces = _getAllChatPlaces();
    if (chatPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = _selectedMapPlaceIndex < chatPlaces.length ? _selectedMapPlaceIndex : 0;
    final p = chatPlaces[safeIndex];
    final name = p['name'] ?? '';
    final description = p['description'] ?? p['address'] ?? '';
    String imageUrl = p['image'] ?? '';
    if (imageUrl.startsWith('/')) {
      imageUrl = '${ApiClient.baseUrl}$imageUrl';
    } else if (imageUrl.isEmpty) {
      imageUrl = _getPlaceImage(name);
    }

    final catName = (p['category']?['name'] ?? '').toString();
    IconData catIcon = Icons.place;
    if (catName.contains('Ẩm thực') || catName.contains('Nhà hàng') || catName.contains('Quán')) {
      catIcon = Icons.restaurant_rounded;
    } else if (catName.contains('Công viên') || catName.contains('Sinh thái')) {
      catIcon = Icons.park_rounded;
    } else if (catName.contains('Chợ') || catName.contains('Mua sắm')) {
      catIcon = Icons.storefront_rounded;
    } else if (catName.contains('Khách sạn') || catName.contains('Resort')) {
      catIcon = Icons.hotel_rounded;
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    catIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mô tả: ${description.isNotEmpty ? description : "Địa điểm tham quan nổi bật tại " + widget.placeName}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF3B82F6),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      SaveToTripBottomSheet.show(
                        context,
                        p,
                        onSaved: () {
                          try {
                            _fetchSavedCount();
                          } catch (_) {}
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm "$name" vào chuyến đi!'),
                              backgroundColor: AppTheme.primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 5),
                          Text(
                            'Thêm vào',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      PlaceDetailBottomSheet.show(
                        context,
                        p,
                        currentItinerary: widget.placeInfo,
                        onTripUpdated: () {
                          try {
                            _fetchSavedCount();
                          } catch (_) {}
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Chi tiết',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      if (p['latitude'] != null && p['longitude'] != null) {
                        final lat = p['latitude'];
                        final lon = p['longitude'];
                        final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.near_me_rounded,
                        color: Color(0xFF0F172A),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isChatHidden = false;
                      });
                      _sendMessage('Hãy cho tôi biết thêm thông tin về $name');
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Hỏi AI',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
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
        ),
      ),
    );
  }
}
