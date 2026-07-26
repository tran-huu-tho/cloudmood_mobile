import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class AppVideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const AppVideoPlayerDialog({super.key, required this.videoUrl});

  static void show(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => AppVideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  @override
  State<AppVideoPlayerDialog> createState() => _AppVideoPlayerDialogState();
}

class _AppVideoPlayerDialogState extends State<AppVideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      _controller.play();
      _controller.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isInitialized)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else if (_hasError)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.white70, size: 48),
                  SizedBox(height: 12),
                  Text('Không thể tải video', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),

          // Top Close Button
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Bottom Controls Bar
          if (_isInitialized && _showControls)
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, VideoPlayerValue value, _) {
                      final maxVal = value.duration.inMilliseconds.toDouble();
                      final currentVal = value.position.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);
                      return Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                value.isPlaying ? _controller.pause() : _controller.play();
                              });
                            },
                          ),
                          Text(
                            _formatDuration(value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Expanded(
                            child: Slider(
                              value: currentVal,
                              min: 0.0,
                              max: maxVal > 0 ? maxVal : 1.0,
                              activeColor: AppTheme.primary,
                              inactiveColor: Colors.white24,
                              onChanged: (val) {
                                _controller.seekTo(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
