import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../screens/place_ai_chat_screen.dart';
import '../services/database_service.dart';
import '../utils/time_utils.dart';
import '../utils/string_utils.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'place_detail_bottom_sheet.dart';
import 'expandable_opening_hours.dart';

class InlinePlaceWhiteCardExtension extends StatefulWidget {
  final Map<String, dynamic> detail;
  final bool isItineraryDetail;
  final VoidCallback onUpdate;
  final VoidCallback? onShowEmojiPicker;

  const InlinePlaceWhiteCardExtension({
    super.key,
    required this.detail,
    required this.isItineraryDetail,
    required this.onUpdate,
    this.onShowEmojiPicker,
  });

  @override
  State<InlinePlaceWhiteCardExtension> createState() =>
      _InlinePlaceWhiteCardExtensionState();
}

class _InlinePlaceWhiteCardExtensionState
    extends State<InlinePlaceWhiteCardExtension> {
  late bool isVisited;
  late double cost;
  List<dynamic> reactions = [];

  String? startTime;
  String? endTime;
  List<String> attachments = [];

  late TextEditingController _noteController;
  late TextEditingController _costController;

  final FocusNode _noteFocus = FocusNode();
  final FocusNode _costFocus = FocusNode();

  Timer? _noteDebounce;
  Timer? _costDebounce;

  @override
  void initState() {
    super.initState();
    _initData();

    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) {
        _updateField({'noteText': _noteController.text});
      }
    });

    _costFocus.addListener(() {
      if (!_costFocus.hasFocus) {
        final parsed = double.tryParse(_costController.text) ?? 0.0;
        if (parsed != cost) {
          cost = parsed;
          _updateField({'cost': parsed});
        }
      }
    });
  }

  @override
  void didUpdateWidget(InlinePlaceWhiteCardExtension oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) {
      _initData();
    }
  }

  void _initData() {
    isVisited =
        widget.detail['isVisited'] == true ||
        widget.detail['is_visited'] == true;
    final costVal = widget.detail['cost'];
    if (costVal is num) {
      cost = costVal.toDouble();
    } else if (costVal is String) {
      cost = double.tryParse(costVal) ?? 0.0;
    } else {
      cost = 0.0;
    }

    final String text =
        widget.detail['noteText'] ?? widget.detail['notetext'] ?? '';
    _noteController = TextEditingController(
      text: text == 'Thêm ghi chú tại đây' ? '' : text,
    );
    _costController = TextEditingController(
      text: cost > 0 ? cost.toStringAsFixed(0) : '',
    );

    startTime = widget.detail['startTime'] ?? widget.detail['starttime'];
    endTime = widget.detail['endTime'] ?? widget.detail['endtime'];

    final att = widget.detail['attachments'];
    if (att != null) {
      if (att is List) {
        attachments = att.map((e) => e.toString()).toList();
      } else if (att is String) {
        try {
          attachments = (json.decode(att) as List)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }
    }

    if (widget.detail['reactions'] != null) {
      if (widget.detail['reactions'] is List) {
        reactions = widget.detail['reactions'] as List;
      } else if (widget.detail['reactions'] is String) {
        try {
          reactions = json.decode(widget.detail['reactions']) as List;
        } catch (_) {}
      }
    }
  }

  void _showEmojiPicker() {
    if (widget.onShowEmojiPicker != null) {
      widget.onShowEmojiPicker!();
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              Navigator.pop(context);
              if (!reactions.contains(emoji.emoji)) {
                setState(() => reactions.add(emoji.emoji));
                _updateField({'reactions': reactions});
                widget.onUpdate();
              }
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    _costDebounce?.cancel();
    _noteFocus.dispose();
    _costFocus.dispose();
    _noteController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _onNoteChanged(String val) {
    if (_noteDebounce?.isActive ?? false) _noteDebounce!.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 1000), () {
      _updateField({'noteText': val});
    });
  }

  void _onCostChanged(String val) {
    if (_costDebounce?.isActive ?? false) _costDebounce!.cancel();
    _costDebounce = Timer(const Duration(milliseconds: 1000), () {
      final parsed = double.tryParse(val) ?? 0.0;
      if (parsed != cost) {
        cost = parsed;
        _updateField({'cost': parsed});
      }
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'CHỌN GIỜ BẮT ĐẦU',
    );
    if (start != null) {
      if (!mounted) return;
      final TimeOfDay? end = await showTimePicker(
        context: context,
        initialTime: start,
        helpText: 'CHỌN GIỜ KẾT THÚC',
      );
      if (end != null) {
        final startStr =
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
        final endStr =
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        setState(() {
          startTime = startStr;
          endTime = endStr;
        });
        _updateField({'startTime': startStr, 'endTime': endStr});
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        attachments.add(result.files.single.name);
      });
      _updateField({'attachments': attachments});
    }
  }

  Future<void> _updateField(Map<String, dynamic> data) async {
    final id = widget.detail['id'] as int;
    await DatabaseService().updateNoteOrDetail(
      id,
      data,
      widget.isItineraryDetail,
    );
    // Don't call onUpdate immediately if user is typing to prevent focus loss
    if (!_noteFocus.hasFocus && !_costFocus.hasFocus) {
      widget.onUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Note field
        TextField(
          controller: _noteController,
          focusNode: _noteFocus,
          onChanged: _onNoteChanged,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.darkText),
          decoration: InputDecoration(
            hintText: 'Thêm ghi chú, liên kết, v.v.',
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.subtitleText),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 12),
        // Action row
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  isVisited = !isVisited;
                });
                _updateField({'isVisited': isVisited});
                widget.onUpdate();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    color: isVisited ? AppTheme.primary : AppTheme.subtitleText,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Đánh dấu ghé thăm',
                    style: TextStyle(
                      color: isVisited
                          ? AppTheme.primary
                          : AppTheme.subtitleText,
                      fontWeight: isVisited ? FontWeight.bold : FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickTime,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: AppTheme.subtitleText,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    startTime != null && endTime != null
                        ? '$startTime - $endTime'
                        : 'Thêm giờ',
                    style: TextStyle(
                      color: AppTheme.subtitleText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickFile,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    color: AppTheme.subtitleText,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    attachments.isNotEmpty
                        ? '${attachments.length} tệp đính kèm'
                        : 'Đính kèm',
                    style: TextStyle(
                      color: AppTheme.subtitleText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\$',
                  style: TextStyle(
                    color: AppTheme.subtitleText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _costController,
                    focusNode: _costFocus,
                    onChanged: _onCostChanged,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Thêm chi phí',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: AppTheme.subtitleText,
                            fontWeight: FontWeight.bold,
                          ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),
        // Reactions
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...reactions.map((emoji) {
              return GestureDetector(
                onTap: () {
                  setState(() => reactions.remove(emoji));
                  _updateField({'reactions': reactions});
                  widget.onUpdate();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 3),
                      const Text(
                        '1',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: _showEmojiPicker,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ), // AppTheme.border
                ),
                child: const Icon(
                  Icons.sentiment_satisfied_alt_outlined,
                  color: Color(0xFF64748B),
                  size: 16,
                ), // AppTheme.subtitleText
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class InlinePlaceBottomInfo extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback? onOpenMap;

  const InlinePlaceBottomInfo({super.key, required this.place, this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    final double rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
    final int userRatingCount =
        (place['userRatingCount'] as num?)?.toInt() ?? 0;

    List<dynamic> subCategories = [];
    final rawSub =
        place['subCategories'] ??
        place['subcategories'] ??
        place['sub_categories'];
    if (rawSub is List) {
      subCategories = List.from(rawSub);
    } else if (rawSub is String) {
      try {
        final decoded = jsonDecode(rawSub);
        if (decoded is List) subCategories = List.from(decoded);
      } catch (_) {}
    }

    // Prepend category if available
    if (place['category'] != null && place['category']['name'] != null) {
      subCategories.insert(0, place['category']['name']);
    }

    // Icon and Color from DB category
    IconData? categoryIcon;
    Color categoryColor = const Color(0xFF3B5998);

    if (place['category'] != null) {
      final cat = place['category'];
      if (cat['iconCode'] != null) {
        categoryIcon = IconData(cat['iconCode'], fontFamily: 'MaterialIcons');
      }
      if (cat['id'] != null) {
        final List<Color> colors = [
          const Color(0xFF3B5998),
          const Color(0xFFE91E63),
          const Color(0xFF009688),
          const Color(0xFFFF9800),
          const Color(0xFF9C27B0),
          const Color(0xFF4CAF50),
          const Color(0xFFF44336),
          const Color(0xFF673AB7),
          const Color(0xFF00BCD4),
        ];
        categoryColor = colors[(cat['id'] as num).toInt() % colors.length];
      }
    }

    final String description =
        place['description'] ?? place['editorialSummary'] ?? '';
    final String duration = place['recommendedDuration']?.toString() ?? '';
    final String address = StringUtils.cleanAddress(place['address'] ?? '');
    final String website = place['website'] ?? '';
    final String phone =
        place['phone'] ??
        place['internationalPhoneNumber'] ??
        place['formattedPhoneNumber'] ??
        place['phoneNumber'] ??
        '';
    final String price = place['price'] ?? '';
    final String priceLevel = place['priceLevel'] ?? '';

    String hoursText = '';
    if (place['openingHours'] != null) {
      hoursText = TimeUtils.getOpeningHoursText(place['openingHours']);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(Icons.search, 'Hỏi AI', true, context, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceAIChatScreen(placeName: place['name'] ?? 'Địa điểm'),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _buildActionButton(
                  Icons.map_outlined,
                  '',
                  false,
                  context,
                  onTap: onOpenMap,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  Icons.directions_outlined,
                  '',
                  false,
                  context,
                ),
                const SizedBox(width: 8),
                _buildActionButton(null, 'Giới thiệu', false, context),
                const SizedBox(width: 8),
                _buildActionButton(Icons.build, 'Hướng dẫn', false, context),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tags
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...subCategories.map((t) => _buildTag(t.toString(), context)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rating > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[700],
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rating',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[900],
                              ),
                        ),
                        if (userRatingCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($userRatingCount)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.subtitleText),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/tripadvisor.jpg',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Tripadvisor',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],

                if (description.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.darkText,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],

                if (duration.isNotEmpty || hoursText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (duration.isNotEmpty)
                          _buildInfoRow(
                            Icons.timer_outlined,
                            'Mọi người thường dành $duration ở đây',
                            context,
                          ),
                        if (duration.isNotEmpty &&
                            place['openingHours'] != null)
                          const SizedBox(height: 12),
                        if (place['openingHours'] != null)
                          ExpandableOpeningHours(
                            hoursData: place['openingHours'],
                          ),
                      ],
                    ),
                  ),

                if (address.isNotEmpty ||
                    website.isNotEmpty ||
                    phone.isNotEmpty ||
                    price.isNotEmpty ||
                    priceLevel.isNotEmpty) ...[
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (price.isNotEmpty || priceLevel.isNotEmpty) ...[
                          _buildInfoRow(
                            Icons.attach_money_rounded,
                            'Mức giá: $price${priceLevel.isNotEmpty ? ' ($priceLevel)' : ''}',
                            context,
                          ),
                          if (address.isNotEmpty ||
                              website.isNotEmpty ||
                              phone.isNotEmpty)
                            const SizedBox(height: 12),
                        ],
                        if (address.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}',
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: _buildInfoRow(
                              Icons.location_on_outlined,
                              address,
                              context,
                              isLink: true,
                              trailing: GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: address),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã sao chép địa chỉ'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: AppTheme.subtitleText,
                                ),
                              ),
                            ),
                          ),
                        if (address.isNotEmpty && website.isNotEmpty)
                          const SizedBox(height: 12),
                        if (website.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse(website);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: _buildInfoRow(
                              Icons.public,
                              website,
                              context,
                              isLink: true,
                            ),
                          ),
                        if (phone.isNotEmpty &&
                            (address.isNotEmpty || website.isNotEmpty))
                          const SizedBox(height: 12),
                        if (phone.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: _buildInfoRow(
                              Icons.phone,
                              phone,
                              context,
                              isLink: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    BuildContext context, {
    bool isLink = false,
    Widget? trailing,
    Widget? customChild,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.subtitleText, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child:
              customChild ??
              (trailing != null
                  ? Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: text),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: trailing,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLink ? AppTheme.primary : AppTheme.darkText,
                        height: 1.4,
                      ),
                    )
                  : Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLink ? AppTheme.primary : AppTheme.darkText,
                        height: 1.4,
                      ),
                    )),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData? icon,
    String label,
    bool isPrimary,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isPrimary ? Colors.white : AppTheme.primary,
                size: 18,
              ),
              if (label.isNotEmpty) const SizedBox(width: 8),
            ],
            if (label.isNotEmpty)
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isPrimary ? Colors.white : AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
