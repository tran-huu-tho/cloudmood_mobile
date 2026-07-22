import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class PlaceAIChatScreen extends StatefulWidget {
  final String placeName;

  const PlaceAIChatScreen({super.key, required this.placeName});

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

  bool _isFullScreen = true;
  bool _isDragging = false;
  double? _dragHeight;
  LatLng? _mapCenter;

  late final _suggestions = [
    'Có phí vào cửa không?',
    'Giờ mở cửa là gì?',
    'Địa điểm này có thể tiếp cận bằng xe lăn không?',
    'Có các tour du lịch có hướng dẫn không?',
    'Tôi nên lên kế hoạch thăm bao lâu?',
    'Có gì gần đây để xem hoặc làm?',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMapData();
    _loadChatSessions();
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
        }
      }
    } catch (e) {
      debugPrint('Error fetching map: $e');
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
    });

    _scrollToBottom();

    try {
      final result = await AiService.sendChatMessage(
        sessionId: _sessionId,
        destination: widget.placeName,
        message: text,
      );

      if (mounted) {
        setState(() {
          _sessionId = result['sessionId'];
          // Reload sessions silently to get the updated title
          _loadChatSessions().then((_) {
            if (_currentTitle == 'Cuộc trò chuyện mới' &&
                _sessions.isNotEmpty) {
              final currentSession = _sessions.firstWhere(
                (s) => s.id == _sessionId,
                orElse: () => _sessions.first,
              );
              setState(() {
                _currentTitle = currentSession.title;
              });
            }
          });

          _messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sessionId: _sessionId!,
              role: 'AI',
              content: result['reply'],
              createdAt: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
                                        _controller.text = s;
                                        _sendMessage();
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
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                return const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final msg = _messages[index];
                              final isUser = msg.role == 'USER';
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
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
                                        : Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    msg.content,
                                    style: TextStyle(
                                      color: isUser
                                          ? Colors.white
                                          : AppTheme.darkText,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
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
                                setState(() {
                                  _isFullScreen = false;
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
        : 45.0;
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
                    options: MapOptions(
                      initialCenter: _mapCenter!,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&apistyle=s.t%3A2%7Cp.v%3Aoff',
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: topPadding + 70,
            right: _isFullScreen ? -60 : 16,
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(Icons.search, color: AppTheme.darkText),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 12),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(Icons.layers_outlined, color: AppTheme.darkText),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
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
                      onPressed: () => Navigator.pop(context),
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
              height: targetSheetHeight,
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
                child: _buildChatBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
