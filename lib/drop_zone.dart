import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;

class DropZone extends StatefulWidget {
  final String label;
  final String? selectedPath;
  final List<String> allowedExtensions;
  final VoidCallback onBrowse;
  final ValueChanged<String> onDropped;
  final IconData icon;

  const DropZone({
    super.key,
    required this.label,
    required this.selectedPath,
    required this.allowedExtensions,
    required this.onBrowse,
    required this.onDropped,
    required this.icon,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.selectedPath != null;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        if (detail.files.isNotEmpty) {
          final path = detail.files.first.path;
          // p.extension returns '.mp4' — strip the leading dot and lowercase
          final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
          if (ext.isNotEmpty && widget.allowedExtensions.contains(ext)) {
            widget.onDropped(path);
          }
          // If extension is not in allowedExtensions, silently ignore
          // (avoids crashing on accidental drops of wrong file types)
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isDragging
              ? const Color(0xFFFF6B35).withValues(alpha: 0.08)
              : hasFile
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDragging
                ? const Color(0xFFFF6B35)
                : hasFile
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFF2A2A2A),
            width: _isDragging ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onBrowse,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasFile
                        ? const Color(0xFFFF6B35).withValues(alpha: 0.15)
                        : const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: hasFile
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF666666),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasFile
                            ? _truncatePath(widget.selectedPath!)
                            : 'Drop file here or click to browse…',
                        style: TextStyle(
                          color: hasFile
                              ? Colors.white
                              : const Color(0xFF555555),
                          fontSize: 13,
                          fontWeight: hasFile
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (hasFile)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 18)
                else
                  const Icon(Icons.upload_file_rounded,
                      color: Color(0xFF444444), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _truncatePath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.length <= 3) return path;
    return '…/${parts[parts.length - 2]}/${parts.last}';
  }
}
