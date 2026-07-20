import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

class TripAIChatScreen extends StatefulWidget {
  final String destination;

  const TripAIChatScreen({super.key, required this.destination});

  @override
  State<TripAIChatScreen> createState() => _TripAIChatScreenState();
}

class _TripAIChatScreenState extends State<TripAIChatScreen> {
  final _controller = TextEditingController();

  bool _isFullScreen = true;
  bool _isDragging = false;
  double? _dragHeight;
  LatLng? _mapCenter;

  late final _suggestions = [
    'Địa điểm ăn uống tốt nhất ở ${widget.destination}',
    'Lịch trình 3 ngày đi ${widget.destination}',
    'Điểm tham quan hàng đầu ở ${widget.destination}',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    // Geocode the destination
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(widget.destination)}&format=json&limit=1',
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

  @override
  void dispose() {
    _controller.dispose();
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
                // Velocity > 0 means dragging down, which means minimizing chat (not full screen)
                _isFullScreen = details.primaryVelocity! < 0;
              } else {
                _isFullScreen = (_dragHeight ?? max) > mid;
              }
              _dragHeight = null;
            });
          },
          child: Container(
            color: Colors.transparent, // To catch gestures
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
                  // Warning banner
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
                        ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Không biết hỏi gì? Thử một số ví dụ sau:',
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
                                    },
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(24),
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
                        ),
                        if (_isFullScreen)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: FloatingActionButton(
                              heroTag: 'ai_chat_map_btn',
                              onPressed: () {
                                setState(() {
                                  _isFullScreen = false;
                                });
                              },
                              backgroundColor: const Color(
                                0xFF1E293B,
                              ), // Dark color
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Còn lại 9 tin nhắn miễn phí',
                              style: TextStyle(
                                color: AppTheme.subtitleText,
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Nhận thêm',
                                style: TextStyle(
                                  color: AppTheme.darkText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: InkWell(
                                  onTap: () {},
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(
                                        0xFFA5B4FC,
                                      ), // Light indigo for the button
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

    // Smooth height transitioning
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
          // 1. Background Map
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

          // 2. Map Action Buttons (Hidden when full screen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: topPadding + 70,
            right: _isFullScreen ? -60 : 16, // Slides in/out from the right
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
                    icon: Icon(
                      Icons.layers_outlined,
                      color: AppTheme.darkText,
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),

          // 3. Dynamic Custom Header (AppBar / Floating Header)
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
                  // Back Button
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
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppTheme.darkText,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  const Spacer(),

                  // Title Pill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isFullScreen ? 0 : 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isFullScreen ? Colors.transparent : Colors.white,
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
                        Text(
                          'Cuộc trò chuyện mới',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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

                  const Spacer(),

                  // Empty space to balance the back button
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // 4. Chat UI Bottom Sheet
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
