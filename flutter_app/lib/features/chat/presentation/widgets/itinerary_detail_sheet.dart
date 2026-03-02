import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/api/trips_api.dart';
import '../../../../core/theme/kakao_theme.dart';
import '../../domain/models.dart';
import '../providers/chat_provider.dart';

class ItineraryDetailSheet extends ConsumerStatefulWidget {
  final String tripId;
  final Map<String, dynamic> item;
  final String dayLabel;
  final List<Message> linkedFiles;
  final List<Map<String, dynamic>> dbLinkedFiles;

  const ItineraryDetailSheet({
    super.key,
    required this.tripId,
    required this.item,
    required this.dayLabel,
    this.linkedFiles = const [],
    this.dbLinkedFiles = const [],
  });

  @override
  ConsumerState<ItineraryDetailSheet> createState() => _ItineraryDetailSheetState();
}

class _ItineraryDetailSheetState extends ConsumerState<ItineraryDetailSheet> {
  late TextEditingController _memoCtrl;
  final List<_LocalPhoto> _localPhotos = [];

  @override
  void initState() {
    super.initState();
    _memoCtrl = TextEditingController(text: widget.item['userMemo'] ?? '');
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
      allowMultiple: true,
    );
    if (result != null) {
      for (final file in result.files) {
        if (file.bytes != null) {
          setState(() {
            _localPhotos.add(_LocalPhoto(name: file.name, bytes: file.bytes!));
          });
          // Upload in background
          final itemLabel = '${widget.dayLabel} - ${widget.item['title']}';
          TripsApi.uploadFile(
            tripId: widget.tripId,
            fileName: file.name,
            mimeType: file.extension == 'png' ? 'image/png' : 'image/jpeg',
            bytes: file.bytes!,
            linkedItem: itemLabel,
          ).then((_) {
            ref.read(attachmentsProvider(widget.tripId).notifier).load();
          }).catchError((_) {});

          // Also add as file message
          ref.read(messagesProvider(widget.tripId).notifier).addMessage(Message(
            id: const Uuid().v4(),
            tripId: widget.tripId,
            role: 'user',
            content: '📸 ${file.name}',
            messageType: MessageType.file,
            fileName: file.name,
            fileType: file.extension == 'png' ? 'image/png' : 'image/jpeg',
            fileSize: file.size,
            fileBytes: file.bytes,
            metadata: {'linkedItem': itemLabel},
            createdAt: DateTime.now(),
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = item['title'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final location = item['location'] as String? ?? '';
    final timeSlot = item['timeSlot'] as String? ?? '';
    final transport = item['transport'] as String? ?? '';
    final costKrw = item['estimatedCostKrw'] as int?;
    final notes = item['notes'] as String? ?? '';

    // Combine local + db photos for this item
    final itemLabel = '${widget.dayLabel} - $title';
    final allDbPhotos = widget.dbLinkedFiles.where((a) {
      final path = a['storage_path'] as String? ?? '';
      final fName = a['file_name'] as String? ?? '';
      // Check linked_item or file association
      return (a['linked_item'] == itemLabel) ||
          widget.linkedFiles.any((f) => f.fileName == fName);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Day badge + time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(widget.dayLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (timeSlot.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90D9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('🕐 $timeSlot', style: const TextStyle(fontSize: 12, color: Color(0xFF4A90D9))),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: KakaoTheme.primary)),
              const SizedBox(height: 12),
              // Description
              if (description.isNotEmpty)
                Text(description, style: const TextStyle(fontSize: 15, color: KakaoTheme.secondary, height: 1.5)),
              const SizedBox(height: 16),
              // Info chips
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  if (location.isNotEmpty)
                    _InfoChip(icon: Icons.location_on, label: location),
                  if (transport.isNotEmpty)
                    _InfoChip(icon: Icons.directions_transit, label: transport),
                  if (costKrw != null && costKrw > 0)
                    _InfoChip(icon: Icons.payments, label: NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(costKrw)),
                ],
              ),
              // Map section
              if (location.isNotEmpty) ...[
                const SizedBox(height: 16),
                _MapPreview(location: location, title: title),
              ],
              // Notes from LLM
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KakaoTheme.myBubble.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(notes, style: const TextStyle(fontSize: 14, color: KakaoTheme.primary, height: 1.4))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // ── Photos section ──
              Row(
                children: [
                  const Text('📸 사진', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('추가'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_localPhotos.isEmpty && widget.linkedFiles.isEmpty && allDbPhotos.isEmpty)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: const Center(
                    child: Text('여행지에서 찍은 사진을 추가해보세요!', style: TextStyle(color: KakaoTheme.secondary, fontSize: 13)),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // In-memory photos from file messages
                      ...widget.linkedFiles.where((f) => (f.fileType ?? '').startsWith('image/')).map((f) =>
                        _PhotoTile(bytes: f.fileBytes as Uint8List?)),
                      // Locally added photos
                      ..._localPhotos.map((p) => _PhotoTile(bytes: p.bytes)),
                      // DB photos
                      ...allDbPhotos.where((a) => (a['file_type'] ?? '').startsWith('image/')).map((a) =>
                        _PhotoTile(url: a['url'] as String?)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // ── Memo section ──
              const Text('📝 메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _memoCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '개인 메모를 남겨보세요...\n예: 예약번호, 주의사항, 감상 등',
                  hintStyle: const TextStyle(color: KakaoTheme.secondary, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _MapPreview extends StatelessWidget {
  final String location;
  final String title;

  const _MapPreview({required this.location, required this.title});

  @override
  Widget build(BuildContext context) {
    final query = Uri.encodeComponent('$title $location');
    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$query';
    final embedUrl = 'https://maps.google.com/maps?q=$query&t=&z=15&ie=UTF8&iwloc=&output=embed';
    final viewType = 'map-$query';

    // Register iframe
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
      final iframe = html.IFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = false;
      return iframe;
    });

    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4A90D9).withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: HtmlElementView(viewType: viewType),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(mapsUrl), mode: LaunchMode.externalApplication),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_new, size: 14, color: const Color(0xFF4A90D9).withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'Google Maps에서 열기',
                style: TextStyle(fontSize: 12, color: const Color(0xFF4A90D9).withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: KakaoTheme.secondary),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary))),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;

  const _PhotoTile({this.bytes, this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          useRootNavigator: false,
          context: context,
          builder: (dialogCtx) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx))],
                ),
                if (bytes != null)
                  Image.memory(bytes!, fit: BoxFit.contain)
                else if (url != null)
                  Image.network(url!, fit: BoxFit.contain),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 120, height: 120,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : url != null
                ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)))
                : const Center(child: Icon(Icons.photo)),
      ),
    );
  }
}

class _LocalPhoto {
  final String name;
  final Uint8List bytes;
  _LocalPhoto({required this.name, required this.bytes});
}
