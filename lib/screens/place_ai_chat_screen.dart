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
        _suggestions = suggestions;
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

  // ============================================
  // Helper Widget Methods
  // ============================================

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
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _mapCenter!,
                            width: 56.0,
                            height: 56.0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isChatHidden = true;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black87.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                        if (_isChatHidden) {
                          setState(() => _isChatHidden = false);
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
    final p =
        widget.placeInfo ??
        {'name': widget.placeName, 'description': '', 'image': ''};
    final name = p['name'] ?? widget.placeName;
    final description = p['description'] ?? p['editorialSummary'] ?? '';
    String imageUrl = p['image'] ?? '';

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 5),
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
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B5998),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Mô tả: $description',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtitleText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
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
                  GestureDetector(
                    onTap: () {
                      SaveToTripBottomSheet.show(
                        context,
                        p,
                        onSaved: () {
                          _fetchSavedCount();
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _savedCount > 0
                            ? Colors.grey[200]
                            : AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _savedCount > 0
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: _savedCount > 0
                                ? Colors.black
                                : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _savedCount > 0
                                ? 'Đã thêm vào $_savedCount chuyến đi'
                                : 'Thêm vào chuyến đi',
                            style: TextStyle(
                              color: _savedCount > 0
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (_savedCount > 0) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.black,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      PlaceDetailBottomSheet.show(
                        context,
                        p,
                        icon: const IconData(
                          0xe4eb,
                          fontFamily: 'MaterialIcons',
                        ),
                        color: const Color(0xFF3B5998),
                        text: '1',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Chi tiết',
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      if (p['latitude'] != null && p['longitude'] != null) {
                        final lat = p['latitude'];
                        final lon = p['longitude'];
                        final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions,
                        color: AppTheme.darkText,
                        size: 18,
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
