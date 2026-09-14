import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/permissions_service.dart';
import '../utils/constants.dart';
import '../services/status_service.dart';
import '../widgets/cyber_background.dart';

typedef AsyncCallback = Future<void> Function();

class MyStatusesScreen extends StatefulWidget {
  static const routeName = '/my-statuses';
  const MyStatusesScreen({super.key});

  @override
  State<MyStatusesScreen> createState() => _MyStatusesScreenState();
}

class _MyStatusesScreenState extends State<MyStatusesScreen> {
  final StatusService _statusService = StatusService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A111F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: kNeonGreen, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'UPDATES',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddStatusDialog(context),
            icon: const Icon(Icons.search_rounded, color: kNeonGreen),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded, color: kNeonGreen),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackground(
              backgroundColors: [
                Color(0xFF02030A),
                Color(0xFF06040E),
                Color(0xFF0C0F1A),
                Color(0xFF03040B),
              ],
              leftAuroraColors: [
                Color(0xFFB23BFF),
                Color(0xFF4A2E9A),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFF00D4FF),
                Color(0xFF1A2D5A),
                Color(0x00000000),
              ],
              fogColor: Color(0x24FFFFFF),
              leftAuroraCenter: Alignment(-0.23, -0.25),
              rightAuroraCenter: Alignment(0.8, -0.15),
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _statusService.getStatuses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: kNeonGreen, strokeWidth: 2));
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Unable to load statuses',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                );
              }

              final allStatuses = snapshot.data ?? [];
              
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // MY STATUS SECTION
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _buildMyStatusSection(),
                  _buildMyStatusPreviewCard(),
                  
                  // DIVIDER
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 0.5,
                      thickness: 0.5,
                    ),
                  ),
                  
                  // RECENT UPDATES SECTION
                  if (allStatuses.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        'RECENT UPDATES',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...allStatuses.map((status) => _buildStatusItem(status)),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sentiment_satisfied_rounded,
                                size: 64,
                                color: kNeonGreen.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            const Text('No updates yet',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // WhatsApp-style "My Status" section with upload button
  Widget _buildMyStatusSection() {
    return GestureDetector(
      onTap: () => _showAddStatusDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Avatar with green border and "+" overlay
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kNeonGreen,
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: kNeonGreen.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ),
                // Green plus button at bottom right
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: kNeonGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF070B14),
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Text section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'My status',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add to your status',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
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

  Widget _buildMyStatusPreviewCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _statusService.getMyStatuses(),
      builder: (context, snapshot) {
        final myStatuses = snapshot.data ?? [];
        if (myStatuses.isEmpty) {
          return const SizedBox.shrink();
        }

        final latestStatus = myStatuses.first;
        final text = latestStatus['text'] as String? ?? '';
        final mediaType = latestStatus['mediaType'] as String? ?? 'text';
        final previewText = text.isNotEmpty
            ? text
            : mediaType == 'text'
                ? 'Text update'
                : 'Shared ${mediaType.toUpperCase()} update';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kNeonGreen.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: kNeonGreen, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your latest update',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previewText.length > 70
                            ? '${previewText.substring(0, 70)}...'
                            : previewText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Individual status item with upload progress indicator
  Widget _buildStatusItem(Map<String, dynamic> statusData) {
    final text = statusData['text'] as String? ?? '';
    final createdAt = statusData['createdAt']?.toString();
    final isUploading = statusData['isUploading'] == true;
    final isMine = statusData['userId'] == _statusService.currentUserId;
    
    String timeText = '';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt).toLocal();
        final now = DateTime.now();
        final diff = now.difference(dateTime);
        
        if (diff.inMinutes < 1) {
          timeText = 'now';
        } else if (diff.inHours < 1) {
          timeText = '${diff.inMinutes}m ago';
        } else if (diff.inDays < 1) {
          timeText = '${diff.inHours}h ago';
        } else {
          timeText = '${diff.inDays}d ago';
        }
      } catch (_) {
        timeText = 'recently';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kNeonGreen,
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: kNeonGreen.withValues(alpha: 0.15),
                    child: Text(
                      text.isNotEmpty ? text[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                if (isUploading)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: kNeonGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF070B14),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.schedule, color: Colors.black, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          statusData['username'] ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMine)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kNeonGreen.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ME',
                            style: TextStyle(
                              color: kNeonGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.length > 54 ? '${text.substring(0, 54)}...' : text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (isMine)
                  InkWell(
                    onTap: () async {
                      final statusId = statusData['id']?.toString();
                      if (statusId == null || statusId.isEmpty) return;
                      try {
                        await _statusService.deleteStatus(statusId);
                        if (mounted) {
                          _showSystemSnackBar(context, 'Status removed');
                        }
                      } catch (_) {
                        if (mounted) {
                          _showSystemSnackBar(context, 'Unable to remove status', isError: true);
                        }
                      }
                    },
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStatusDialog(BuildContext context) {
    final controller = TextEditingController();
    final dialogContext = context;
    String selectedType = 'text';

    String? selectedFilePath;

    Future<void> pickStatusMedia() async {
      final permissionGranted = await PermissionsService().requestStoragePermission();
      if (!permissionGranted) {
        if (!dialogContext.mounted) return;
        _showSystemSnackBar(dialogContext, 'Storage permission required to select media', isError: true);
        return;
      }

      FileType type = FileType.any;
      if (selectedType == 'image') {
        type = FileType.image;
      } else if (selectedType == 'video') {
        type = FileType.video;
      } else if (selectedType == 'audio') {
        type = FileType.audio;
      }

      final result = await FilePicker.pickFile(type: type);
      if (!context.mounted) return;
      if (result != null && result.path != null) {
        selectedFilePath = result.path;
        if (selectedFilePath != null) {
          _showSystemSnackBar(context, 'Selected $selectedType file.');
        }
      }
    }

    _showSystemDialog(
      context,
      title: 'Post Status',
      child: _buildStatusForm(controller, selectedType, selectedFilePath, (value) {
        selectedType = value;
        selectedFilePath = null;
      }, pickStatusMedia),
      onConfirm: () async {
        final text = controller.text.trim();
        if (selectedType == 'text' && text.isEmpty) {
          _showSystemSnackBar(context, 'Status text cannot be empty', isError: true);
          return;
        }
        if (selectedType != 'text' && selectedFilePath == null) {
          _showSystemSnackBar(context, 'Please choose a $selectedType file to upload', isError: true);
          return;
        }

        Navigator.pop(context);
        try {
          String? mediaUrl;
          if (selectedFilePath != null) {
            mediaUrl = await _statusService.uploadStatusMedia(selectedFilePath!, selectedType);
          }
          await _statusService.postStatus(text: selectedType == 'text' ? text : (text.isNotEmpty ? text : ''), mediaType: selectedType, mediaUrl: mediaUrl);
          if (context.mounted) {
            _showSystemSnackBar(context, 'Status posted successfully');
          }
        } catch (e) {
          if (context.mounted) {
            _showSystemSnackBar(context, 'Failed to post status: $e', isError: true);
          }
        }
      },
      confirmLabel: 'POST',
    );
  }

  // --- Pro System UI Helpers ---

  void _showSystemDialog(BuildContext context,
      {required String title,
      required Widget child,
      required Future<void> Function() onConfirm,
      String confirmLabel = 'POST'}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1E36),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            child: child,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('ABORT', style: TextStyle(color: Colors.white24))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kNeonPurple),
            onPressed: () async {
              await onConfirm();
            },
            child: Text(confirmLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusForm(TextEditingController controller, String type, String? selectedFilePath,
      Function(String) onTypeChange, AsyncCallback? onPickMedia) {
    return StatefulBuilder(
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: type == 'text'
                  ? 'Input status message...'
                  : 'Optional caption for your $type status...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF070B14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          if (type != 'text') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeonGreen,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      if (onPickMedia != null) {
                        await onPickMedia();
                      }
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Choose file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              selectedFilePath != null ? selectedFilePath.split('/').last : 'No $type selected yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          _buildTypeSelector(type, (val) {
            onTypeChange(val);
            setDialogState(() {});
          }),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String current, Function(String) onSelect) {
    final types = ['text', 'image', 'video', 'audio'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: types.map((t) {
        final isSelected = current == t;
        return GestureDetector(
          onTap: () => onSelect(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? kNeonPurple.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: isSelected ? kNeonPurple : Colors.white10),
            ),
            child: Text(t.toUpperCase(),
                style: TextStyle(
                    color: isSelected ? kNeonPurple : Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
  // --- FINAL UTILITIES FOR MY_STATUSES ---

  void _showSystemSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        backgroundColor: isError ? Colors.redAccent : kNeonPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
} // Final closure of _MyStatusesScreenState
