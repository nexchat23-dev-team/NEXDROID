import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_media_viewer.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMine;
  final String senderName;
  final String? senderAvatar;
  final bool isGroup;
  final bool isAdmin;
  final bool isPlayingAudio;
  final double audioProgress;
  final VoidCallback? onPlayAudio;
  final ValueChanged<Map<String, dynamic>>? onReply;
  final ValueChanged<String>? onDelete;
  final void Function(String emoji)? onToggleReaction;

  static const Color _neonPurpleStart = Color(0xFF8B32EB);
  static const Color _neonPurpleEnd = Color(0xFF671FB3);
  static const Color _receivedBubbleBg = Color(0xFF1B1333);
  static const Color _accentCyan = Color(0xFF00E5FF);
  static const Color _subTextGrey = Color(0xFF9E8DBE);
  static const Color _whiteText = Color(0xFFF5EFFF);

  const MessageBubble({
    super.key,
    required this.data,
    required this.isMine,
    required this.senderName,
    this.senderAvatar,
    this.isGroup = false,
    this.isAdmin = false,
    this.isPlayingAudio = false,
    this.audioProgress = 0.0,
    this.onPlayAudio,
    this.onReply,
    this.onDelete,
    this.onToggleReaction,
  });

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '';
    try {
      if (rawTime is DateTime) {
        final h = rawTime.hour.toString().padLeft(2, '0');
        final m = rawTime.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
      final dt = DateTime.parse(rawTime.toString()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, int> _aggregateReactions() {
    final raw = data['reactions'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, val) {
        if (val != null) {
          final emoji = val.toString();
          counts[emoji] = (counts[emoji] ?? 0) + 1;
        }
      });
    }
    return counts;
  }

  static IconData getReactionIcon(String key) {
    switch (key) {
      case 'like':
      case '\uD83D\uDC4D':
        return Icons.thumb_up_rounded;
      case 'love':
      case '\u2764\uFE0F':
      case '\u2764':
        return Icons.favorite_rounded;
      case 'fire':
      case '\uD83D\uDD25':
        return Icons.local_fire_department_rounded;
      case 'laugh':
      case '\uD83D\uDE02':
        return Icons.sentiment_very_satisfied_rounded;
      case 'wow':
      case '\uD83D\uDE2E':
        return Icons.sentiment_neutral_rounded;
      case 'rocket':
      case '\uD83D\uDE80':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  void _showActionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final reactionOptions = [
      {'key': 'like', 'icon': Icons.thumb_up_rounded, 'color': const Color(0xFF00E5FF)},
      {'key': 'love', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFFF2A6D)},
      {'key': 'fire', 'icon': Icons.local_fire_department_rounded, 'color': const Color(0xFFFF9800)},
      {'key': 'laugh', 'icon': Icons.sentiment_very_satisfied_rounded, 'color': const Color(0xFFFFD700)},
      {'key': 'wow', 'icon': Icons.sentiment_neutral_rounded, 'color': const Color(0xFFB44FFF)},
      {'key': 'rocket', 'icon': Icons.rocket_launch_rounded, 'color': const Color(0xFF00FF66)},
    ];
    final messageId = data['id']?.toString() ?? '';
    final text = data['text']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140B28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              // Icon reaction selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: reactionOptions.map((opt) {
                    final key = opt['key'] as String;
                    final icon = opt['icon'] as IconData;
                    final color = opt['color'] as Color;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onToggleReaction?.call(key);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12, height: 1),
              if (text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: _accentCyan),
                  title: const Text('Copy Text', style: TextStyle(color: _whiteText)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard')),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: _neonPurpleStart),
                title: const Text('Reply', style: TextStyle(color: _whiteText)),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply?.call({
                    'id': messageId,
                    'text': text.isNotEmpty
                        ? text
                        : (data['type'] == 'image'
                            ? 'Photo'
                            : (data['type'] == 'audio' ? 'Voice note' : 'Document')),
                    'senderName': isMine ? 'You' : senderName,
                  });
                },
              ),
              if (isMine || isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call(messageId);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(data['timestamp'] ?? data['createdAt']);
    final type = data['type']?.toString() ?? 'text';
    final text = data['text']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? (type == 'image' ? data['fileUrl']?.toString() : null);
    final fileName = data['fileName']?.toString() ?? 'Document';
    final fileSize = data['fileSize'] as int?;
    final replyText = data['replyText']?.toString();
    final replySender = data['replySender']?.toString();
    final reactions = _aggregateReactions();
    final messageId = data['id']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine && isGroup) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2B1B4A),
                  backgroundImage: senderAvatar != null && senderAvatar!.isNotEmpty
                      ? NetworkImage(senderAvatar!)
                      : null,
                  child: senderAvatar == null || senderAvatar!.isEmpty
                      ? Text(
                          senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: _accentCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sender name for group chats
                    if (!isMine && isGroup)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              senderName,
                              style: const TextStyle(
                                color: _accentCyan,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _neonPurpleStart.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: _neonPurpleStart,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Quoted reply if any
                    if (replyText != null && replyText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: const Border(
                            left: BorderSide(color: _accentCyan, width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replySender ?? 'User',
                              style: const TextStyle(
                                color: _accentCyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              replyText,
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                    // Bubble container with swipe gesture
                    GestureDetector(
                      onLongPress: () => _showActionSheet(context),
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity!.abs() > 200) {
                          HapticFeedback.selectionClick();
                          onReply?.call({
                            'id': messageId,
                            'text': text.isNotEmpty
                                ? text
                                : (type == 'image'
                                    ? 'Photo'
                                    : (type == 'audio' ? 'Voice note' : 'Document')),
                            'senderName': isMine ? 'You' : senderName,
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: type == 'image' ? 6 : 14,
                          vertical: type == 'image' ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMine
                              ? const LinearGradient(
                                  colors: [_neonPurpleStart, _neonPurpleEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isMine ? null : _receivedBubbleBg,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMine ? 18 : 4),
                            bottomRight: Radius.circular(isMine ? 4 : 18),
                          ),
                          border: Border.all(
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isMine
                                  ? _neonPurpleStart.withValues(alpha: 0.22)
                                  : Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 1. Image content
                            if (type == 'image' && imageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: GestureDetector(
                                  onTap: () => ChatMediaViewer.show(
                                    context,
                                    imageUrl: imageUrl,
                                    title: senderName,
                                    subtitle: timeStr,
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    width: 220,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        width: 220,
                                        height: 180,
                                        color: Colors.black26,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded /
                                                    progress.expectedTotalBytes!
                                                : null,
                                            color: _accentCyan,
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 220,
                                      height: 140,
                                      color: Colors.black26,
                                      child: const Center(
                                        child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 36),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (text.isNotEmpty && !text.startsWith('[Shared Image'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
                                  child: Text(
                                    text,
                                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                                  ),
                                ),
                            ]
                            // 2. Audio content
                            else if (type == 'audio') ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: onPlayAudio,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: _accentCyan,
                                      child: Icon(
                                        isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Voice Audio Shard',
                                        style: TextStyle(
                                          color: _whiteText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 130,
                                        child: LinearProgressIndicator(
                                          value: isPlayingAudio ? audioProgress : 0.0,
                                          backgroundColor: Colors.white12,
                                          valueColor: const AlwaysStoppedAnimation<Color>(_accentCyan),
                                          minHeight: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ]
                            // 3. Document / File content
                            else if (type == 'file' || type == 'document') ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.insert_drive_file_rounded, color: _accentCyan, size: 26),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fileName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (fileSize != null && fileSize > 0)
                                          Text(
                                            _formatFileSize(fileSize),
                                            style: const TextStyle(color: _subTextGrey, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ]
                            // 4. Standard text
                            else ...[
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],

                            const SizedBox(height: 3),
                            // Timestamp and read ticks
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isMine ? Colors.white70 : Colors.white38,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.done_all_rounded,
                                    size: 14,
                                    color: Color(0xFF00FFC2),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Reactions row below bubble
                    if (reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                          spacing: 4,
                          children: reactions.entries.map((entry) {
                            return GestureDetector(
                              onTap: () => onToggleReaction?.call(entry.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF261247),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _neonPurpleStart.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(getReactionIcon(entry.key), size: 12, color: _accentCyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${entry.value}',
                                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
