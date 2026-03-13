import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_svg/flutter_svg.dart';

import 'console_output.dart';
import 'drop_zone.dart';
import 'exiftool_service.dart';

// ── Font helpers (system only, no network) ────────────────────────────────────
TextStyle _inter({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.white,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: '.AppleSystemUIFont',
      fontFamilyFallback: const ['Inter', 'Helvetica Neue', 'Arial'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );

TextStyle _mono({
  double fontSize = 12,
  Color color = Colors.white,
  FontWeight fontWeight = FontWeight.normal,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: const ['Menlo', 'Monaco', 'Courier New', 'monospace'],
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );

// ── Page ──────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // ── Tab controller ────────────────────────────────────────────────────────
  late final TabController _tabCtrl;

  // ── Single mode state ─────────────────────────────────────────────────────
  String? _originalPath;
  String? _encodedPath;
  bool _renameAfterFix = false;
  bool _fixFileDates = true;
  bool _isProcessing = false;

  // ── Batch mode state ──────────────────────────────────────────────────────
  String? _batchOriginalFolder;
  String? _batchEncodedFolder;
  String? _batchOutputFolder;
  bool _batchRenameAfterFix = false;
  bool _batchFixFileDates = true;
  bool _isBatchProcessing = false;
  bool _batchOriginalDragging = false;
  bool _batchEncodedDragging = false;
  bool _batchOutputDragging = false;

  // ── Shared state ──────────────────────────────────────────────────────────
  bool? _exiftoolAvailable;
  String _exiftoolVersion = '';

  final _cameraNameCtrl      = TextEditingController(text: 'a6700');
  final _batchCameraNameCtrl = TextEditingController(text: 'a6700');
  final List<LogEntry> _logs = [];
  final _scrollCtrl          = ScrollController();

  static const _videoExts = ['mp4', 'mov', 'mkv', 'avi', 'm4v'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkExifTool();
    _cameraNameCtrl.addListener(() => setState(() {}));
    _batchCameraNameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _cameraNameCtrl.dispose();
    _batchCameraNameCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── ExifTool check ────────────────────────────────────────────────────────
  Future<void> _checkExifTool() async {
    ExifToolService.clearCache();
    _log('Searching for ExifTool…', LogLevel.system);
    final available = await ExifToolService.isAvailable();
    String version = '', foundPath = '';
    if (available) {
      version   = await ExifToolService.getVersion();
      foundPath = await ExifToolService.resolvedPath();
    }
    if (!mounted) return;
    setState(() {
      _exiftoolAvailable = available;
      _exiftoolVersion   = version;
    });
    if (available) {
      _log('ExifTool v$version found at: $foundPath', LogLevel.success);
    } else {
      _log('ExifTool not found. Searched these paths:', LogLevel.error);
      for (final path in ExifToolService.checkedPaths()) {
        _log('  $path', LogLevel.error);
      }
      _log('Click "ExifTool missing" pill above for install steps.', LogLevel.warning);
    }
  }

  // ── Log ───────────────────────────────────────────────────────────────────
  void _log(String msg, [LogLevel lvl = LogLevel.info]) {
    setState(() => _logs.add(LogEntry(message: msg, level: lvl)));
    _scrollToBottom();
  }

  void _logBatch(List<LogEntry> entries) {
    setState(() => _logs.addAll(entries));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── File pickers ──────────────────────────────────────────────────────────
  Future<void> _pickOriginal() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: _videoExts);
    if (result?.files.single.path != null) {
      setState(() => _originalPath = result!.files.single.path);
      _log('Original: ${_trunc(_originalPath!)}');
    }
  }

  Future<void> _pickEncoded() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: _videoExts);
    if (result?.files.single.path != null) {
      setState(() => _encodedPath = result!.files.single.path);
      _log('Encoded: ${_trunc(_encodedPath!)}');
    }
  }

  Future<void> _pickBatchFolder(String slot) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      setState(() {
        if (slot == 'original') _batchOriginalFolder = path;
        if (slot == 'encoded')  _batchEncodedFolder  = path;
        if (slot == 'output')   _batchOutputFolder   = path;
      });
      _log('${slot[0].toUpperCase()}${slot.substring(1)} folder: ${_trunc(path)}');
    }
  }

  // ── Single fix ────────────────────────────────────────────────────────────
  Future<void> _fixMetadata() async {
    if (_originalPath == null || _encodedPath == null) {
      _showSnack('Please select both the original and encoded video files.\n'
          'Tip: you can select the same file for both to only fix the UTC timestamp.');
      return;
    }
    if (_exiftoolAvailable != true) { _showExifToolDialog(); return; }

    setState(() => _isProcessing = true);
    _log('─' * 50, LogLevel.system);
    _log('Starting metadata fix…', LogLevel.system);
    _log('  Original : ${_trunc(_originalPath!)}');
    _log('  Encoded  : ${_trunc(_encodedPath!)}');

    try {
      _log('Running ExifTool…');
      final result = await ExifToolService.fixMetadata(
          originalPath: _originalPath!, encodedPath: _encodedPath!);
      _printResult(result);

      if (result.exitCode == 0) {
        _log('Metadata fix completed successfully.', LogLevel.success);

        if (_fixFileDates) {
          _log('Syncing file system timestamps to CreateDate…');
          final fr = await ExifToolService.fixFileDates(filePath: _encodedPath!);
          _printResult(fr);
          _log(
            fr.exitCode == 0
                ? 'File timestamps updated.'
                : 'Timestamp sync failed (exit ${fr.exitCode}).',
            fr.exitCode == 0 ? LogLevel.success : LogLevel.error,
          );
        }

        if (_renameAfterFix) {
          final cam = _cameraNameCtrl.text.trim();
          _log(cam.isEmpty ? 'Renaming → [date]' : 'Renaming → [date] - $cam');
          final rr = await ExifToolService.renameFile(
              encodedPath: _encodedPath!, userText: cam);
          _printResult(rr);
          if (rr.exitCode == 0) {
            _log('File renamed successfully.', LogLevel.success);
            final newPath = _parseRenamedPath(rr.stdout.toString(), _encodedPath!);
            if (newPath != null) setState(() => _encodedPath = newPath);
          } else {
            _log('Rename failed (exit ${rr.exitCode}).', LogLevel.error);
          }
        }
      } else {
        _log('ExifTool exited with code ${result.exitCode}.', LogLevel.error);
      }
    } catch (e) {
      _log('Unexpected error: $e', LogLevel.error);
    } finally {
      setState(() => _isProcessing = false);
      _log('Done.', LogLevel.system);
    }
  }

  // ── Batch fix ─────────────────────────────────────────────────────────────
  Future<void> _runBatch() async {
    if (_batchOriginalFolder == null || _batchEncodedFolder == null) {
      _showSnack('Please select both the Originals folder and the Encoded folder.');
      return;
    }
    if (_exiftoolAvailable != true) { _showExifToolDialog(); return; }

    setState(() => _isBatchProcessing = true);
    _log('─' * 50, LogLevel.system);
    _log('Starting batch process…', LogLevel.system);
    _log('  Originals : ${_trunc(_batchOriginalFolder!)}');
    _log('  Encoded   : ${_trunc(_batchEncodedFolder!)}');
    if (_batchOutputFolder != null) {
      _log('  Output    : ${_trunc(_batchOutputFolder!)}');
    } else {
      _log('  Output    : overwrite in-place');
    }

    try {
      final originalsDir = Directory(_batchOriginalFolder!);
      final encodedDir   = Directory(_batchEncodedFolder!);

      final originals = originalsDir.listSync().whereType<File>().toList();

      if (originals.isEmpty) {
        _log('No files found in originals folder.', LogLevel.warning);
        setState(() => _isBatchProcessing = false);
        return;
      }

      _log('Found ${originals.length} file(s) in originals folder.');

      // Build a lookup map of baseName → [files] from the encoded folder once,
      // rather than scanning the directory again for every original file.
      final encodedMap = <String, List<File>>{};
      for (final f in encodedDir.listSync().whereType<File>()) {
        final base = p.basenameWithoutExtension(f.path);
        encodedMap.putIfAbsent(base, () => []).add(f);
      }

      int matched = 0, succeeded = 0, failed = 0;

      for (final originalFile in originals) {
        final baseName     = p.basenameWithoutExtension(originalFile.path);
        final encodedFiles = encodedMap[baseName] ?? [];

        if (encodedFiles.isEmpty) {
          _log('  [$baseName] No match — skipped.', LogLevel.warning);
          continue;
        }

        matched++;

        for (final encodedFile in encodedFiles) {
          String targetPath = encodedFile.path;

          // Copy to output folder if specified
          if (_batchOutputFolder != null) {
            final destPath = p.join(_batchOutputFolder!, p.basename(encodedFile.path));
            await File(encodedFile.path).copy(destPath);
            targetPath = destPath;
            _log('  [$baseName] Copied to output folder.');
          }

          _log('  [$baseName] Fixing: ${p.basename(targetPath)}…');
          final entries = <LogEntry>[];

          final result = await ExifToolService.fixMetadata(
              originalPath: originalFile.path, encodedPath: targetPath);

          for (final line in result.stdout.toString().trim().split(RegExp(r'\r?\n'))) {
            if (line.trim().isNotEmpty) {
              entries.add(LogEntry(message: '    ${line.trim()}', level: LogLevel.info));
            }
          }
          for (final line in result.stderr.toString().trim().split(RegExp(r'\r?\n'))) {
            if (line.trim().isNotEmpty) {
              entries.add(LogEntry(message: '    ${line.trim()}', level: LogLevel.warning));
            }
          }

          if (result.exitCode != 0) {
            entries.add(LogEntry(
                message: '  [$baseName] Failed (exit ${result.exitCode}).',
                level: LogLevel.error));
            _logBatch(entries);
            failed++;
            continue;
          }

          if (_batchFixFileDates) {
            final fr = await ExifToolService.fixFileDates(filePath: targetPath);
            for (final line in fr.stdout.toString().trim().split(RegExp(r'\r?\n'))) {
              if (line.trim().isNotEmpty) {
                entries.add(LogEntry(message: '    ${line.trim()}', level: LogLevel.info));
              }
            }
          }

          bool renameFailed = false;
          if (_batchRenameAfterFix) {
            final cam = _batchCameraNameCtrl.text.trim();
            final rr  = await ExifToolService.renameFile(encodedPath: targetPath, userText: cam);
            for (final line in rr.stdout.toString().trim().split(RegExp(r'\r?\n'))) {
              if (line.trim().isNotEmpty) {
                entries.add(LogEntry(message: '    ${line.trim()}', level: LogLevel.info));
              }
            }
            if (rr.exitCode != 0) {
              entries.add(LogEntry(message: '  [$baseName] Rename failed.', level: LogLevel.error));
              renameFailed = true;
            }
          }

          if (renameFailed) {
            failed++;
          } else {
            entries.add(LogEntry(message: '  [$baseName] ✓ Done.', level: LogLevel.success));
            succeeded++;
          }
          _logBatch(entries);
        }
      }

      _log('─' * 50, LogLevel.system);
      _log(
        'Batch complete. Matched: $matched | Success: $succeeded | Failed: $failed',
        failed > 0 ? LogLevel.warning : LogLevel.success,
      );
    } catch (e) {
      _log('Batch error: $e', LogLevel.error);
    } finally {
      setState(() => _isBatchProcessing = false);
      _log('Done.', LogLevel.system);
    }
  }

  // ── Parse renamed path from exiftool stdout ───────────────────────────────
  String? _parseRenamedPath(String stdout, String originalPath) {
    try {
      final dir   = p.dirname(originalPath);
      final arrow = stdout.indexOf('-->');
      if (arrow == -1) return null;
      final newName = stdout
          .substring(arrow + 3)
          .trim()
          .replaceAll("'", '')
          .replaceAll('"', '')
          .split(RegExp(r'\r?\n'))
          .first
          .trim()
          .replaceAll('\r', '');
      if (newName.isEmpty) return null;
      return p.join(dir, newName);
    } catch (_) {
      return null;
    }
  }

  void _printResult(ProcessResult r) {
    final entries = <LogEntry>[];
    for (final line in r.stdout.toString().trim().split(RegExp(r'\r?\n'))) {
      if (line.trim().isNotEmpty) {
        entries.add(LogEntry(message: line.trim(), level: LogLevel.info));
      }
    }
    for (final line in r.stderr.toString().trim().split(RegExp(r'\r?\n'))) {
      if (line.trim().isNotEmpty) {
        entries.add(LogEntry(message: line.trim(), level: LogLevel.warning));
      }
    }
    if (entries.isNotEmpty) _logBatch(entries);
  }

  // ── Snack / dialogs ───────────────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF333333),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _showExifToolDialog() {
    if (!mounted) return;
    final os    = Platform.isMacOS ? 'macOS' : Platform.isWindows ? 'Windows' : 'Linux';
    final steps = ExifToolService.installInstructions();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF5350)),
          const SizedBox(width: 10),
          Text('ExifTool Not Found on $os'),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ExifTool was not found. Install it using one of these methods:',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: line.startsWith('  ')
                        ? _mono(color: const Color(0xFF4CAF50), fontSize: 11)
                        : const TextStyle(color: Color(0xFF888888), fontSize: 11,
                            fontWeight: FontWeight.w600),
                  ),
                )).toList(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _checkExifTool(); },
            child: const Text('Re-check'),
          ),
        ],
      ),
    );
  }

  void _showInputHelp() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.help_outline_rounded, color: Color(0xFFFF6B35)),
          SizedBox(width: 10), Text('How to use AlphaFix'),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _helpCard(
              icon: Icons.swap_horiz_rounded,
              title: 'Normal use - two different files',
              body: 'INPUT  →  original file straight from your camera\n'
                  'OUTPUT →  the re-encoded or compressed version\n\n'
                  'AlphaFix copies the creation date, GPS, camera model, make '
                  'and lens info from the original into the encoded file.',
            ),
            const SizedBox(height: 12),
            _helpCard(
              icon: Icons.schedule_rounded,
              title: 'UTC timestamp fix - same file for both',
              body: 'If your videos from SONY/other Camera show wrong date & time in Ente, '
                  'Google Photos, iCloud or any cloud service, it is usually '
                  'because those apps read the UTC-based QuickTime tag instead '
                  'of the local-time tag.\n\n'
                  'Select the SAME file for INPUT and OUTPUT. AlphaFix will '
                  'rewrite the QuickTime UTC tag in-place so the date is '
                  'correct everywhere.',
            ),
          ]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _helpCard({required IconData icon, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: const Color(0xFFFF6B35)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(
            color: Color(0xFF999999), fontSize: 11, height: 1.5)),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _trunc(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.length <= 3 ? path : '…/${parts[parts.length - 2]}/${parts.last}';
  }

  bool get _canFix =>
      _originalPath != null && _encodedPath != null &&
      !_isProcessing && _exiftoolAvailable == true;

  bool get _canBatchFix =>
      _batchOriginalFolder != null && _batchEncodedFolder != null &&
      !_isBatchProcessing && _exiftoolAvailable == true;

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _titleBar(),
        Expanded(child: Row(children: [
          SizedBox(width: 360, child: _leftPanel()),
          Container(width: 1, color: const Color(0xFF1E1E1E)),
          Expanded(child: _consolePanel()),
        ])),
        _footer(),
      ]),
    );
  }

  // ── Title bar ─────────────────────────────────────────────────────────────
  Widget _titleBar() {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        SvgPicture.asset('assets/logo.svg', width: 30, height: 30),
        const SizedBox(width: 10),
        Text('AlphaFix',
            style: _inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
        const SizedBox(width: 5),
        Text('v1.0.0', style: _inter(fontSize: 11, color: const Color(0xFF444444))),
        const SizedBox(width: 8),
        Text('Metadata Repair Tool',
            style: _inter(fontSize: 12, color: const Color(0xFF555555))),
        const Spacer(),
        if (_exiftoolAvailable != null) _exiftoolPill(),
      ]),
    );
  }

  Widget _exiftoolPill() {
    final ok    = _exiftoolAvailable!;
    final color = ok ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    return GestureDetector(
      onTap: ok ? _checkExifTool : _showExifToolDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            ok ? 'ExifTool v$_exiftoolVersion' : 'ExifTool missing — click to retry',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  // ── Left panel with tabs ──────────────────────────────────────────────────
  Widget _leftPanel() {
    return Column(children: [
      Container(
        color: const Color(0xFF111111),
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFFF6B35),
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF555555),
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
          tabs: const [
            Tab(text: 'SINGLE'),
            Tab(text: 'BATCH'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [_singlePanel(), _batchPanel()],
        ),
      ),
    ]);
  }

  // ── Single panel ──────────────────────────────────────────────────────────
  Widget _singlePanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _label('INPUT'),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _showInputHelp,
            child: const Tooltip(
              message: 'Click to learn about INPUT / OUTPUT and the UTC fix tip',
              child: Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF555555)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        DropZone(
          label: 'ORIGINAL FILE (camera source)',
          selectedPath: _originalPath,
          allowedExtensions: _videoExts,
          onBrowse: _pickOriginal,
          onDropped: (path) {
            setState(() => _originalPath = path);
            _log('Original dropped: ${_trunc(path)}');
          },
          icon: Icons.video_file_rounded,
        ),
        const SizedBox(height: 20),
        Row(children: [
          _label('OUTPUT'),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _showInputHelp,
            child: const Tooltip(
              message: 'Select the same file as INPUT to fix UTC timestamp only',
              child: Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF555555)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        DropZone(
          label: 'ENCODED / COMPRESSED FILE',
          selectedPath: _encodedPath,
          allowedExtensions: _videoExts,
          onBrowse: _pickEncoded,
          onDropped: (path) {
            setState(() => _encodedPath = path);
            _log('Encoded dropped: ${_trunc(path)}');
          },
          icon: Icons.movie_creation_rounded,
        ),
        if (_originalPath != null &&
            _encodedPath   != null &&
            _originalPath  == _encodedPath) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.25)),
            ),
            child: const Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFFF6B35)),
              SizedBox(width: 8),
              Expanded(child: Text(
                'UTC-fix mode — will rewrite QuickTime UTC tag in-place.',
                style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11, height: 1.4),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        _optionsSection(
          fixFileDates: _fixFileDates,
          onFixFileDatesChanged: (v) => setState(() => _fixFileDates = v ?? true),
          renameAfterFix: _renameAfterFix,
          onRenameChanged: (v) => setState(() => _renameAfterFix = v ?? false),
          cameraCtrl: _cameraNameCtrl,
        ),
        const SizedBox(height: 24),
        _actionButton(
          label: 'Fix Metadata',
          icon: Icons.auto_fix_high_rounded,
          enabled: _canFix,
          isProcessing: _isProcessing,
          onPressed: _fixMetadata,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            setState(() {
              _originalPath = null;
              _encodedPath  = null;
              _logs.clear();
            });
            _log('Cleared.', LogLevel.system);
          },
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF555555)),
          child: const Text('Clear All', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Batch panel ───────────────────────────────────────────────────────────
  Widget _batchPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // disclaimer
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB74D).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.28)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFFFB74D)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Files are matched by base filename — the extension can differ, but the '
              'name before the dot must be exactly the same in both folders.\n'
              'e.g. "A001.MP4" (original) will match "A001.mov" (encoded).',
              style: TextStyle(color: Color(0xFFFFB74D), fontSize: 10.5, height: 1.5),
            )),
          ]),
        ),

        const SizedBox(height: 16),
        _label('ORIGINALS FOLDER'),
        const SizedBox(height: 8),
        _folderDropZone(
          hint: 'Folder with original camera files',
          selectedPath: _batchOriginalFolder,
          isDragging: _batchOriginalDragging,
          icon: Icons.folder_rounded,
          onBrowse: () => _pickBatchFolder('original'),
          onDragEnter: () => setState(() => _batchOriginalDragging = true),
          onDragExit:  () => setState(() => _batchOriginalDragging = false),
          onDropped: (path) {
            setState(() { _batchOriginalFolder = path; _batchOriginalDragging = false; });
            _log('Originals folder: ${_trunc(path)}');
          },
        ),

        const SizedBox(height: 14),
        _label('ENCODED FOLDER'),
        const SizedBox(height: 8),
        _folderDropZone(
          hint: 'Folder with re-encoded / compressed files',
          selectedPath: _batchEncodedFolder,
          isDragging: _batchEncodedDragging,
          icon: Icons.folder_copy_rounded,
          onBrowse: () => _pickBatchFolder('encoded'),
          onDragEnter: () => setState(() => _batchEncodedDragging = true),
          onDragExit:  () => setState(() => _batchEncodedDragging = false),
          onDropped: (path) {
            setState(() { _batchEncodedFolder = path; _batchEncodedDragging = false; });
            _log('Encoded folder: ${_trunc(path)}');
          },
        ),

        const SizedBox(height: 14),
        Row(children: [
          _label('OUTPUT FOLDER'),
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Optional. Files are copied here before fixing.\nLeave empty to overwrite encoded files in-place.',
            child: Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF555555)),
          ),
          const SizedBox(width: 6),
          const Text('optional',
              style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 9.5, letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 8),
        _folderDropZone(
          hint: 'Output folder (leave empty to overwrite in-place)',
          selectedPath: _batchOutputFolder,
          isDragging: _batchOutputDragging,
          icon: Icons.drive_folder_upload_rounded,
          onBrowse: () => _pickBatchFolder('output'),
          onDragEnter: () => setState(() => _batchOutputDragging = true),
          onDragExit:  () => setState(() => _batchOutputDragging = false),
          onDropped: (path) {
            setState(() { _batchOutputFolder = path; _batchOutputDragging = false; });
            _log('Output folder: ${_trunc(path)}');
          },
          clearable: _batchOutputFolder != null,
          onClear: () => setState(() => _batchOutputFolder = null),
        ),

        const SizedBox(height: 18),
        _optionsSection(
          fixFileDates: _batchFixFileDates,
          onFixFileDatesChanged: (v) => setState(() => _batchFixFileDates = v ?? true),
          renameAfterFix: _batchRenameAfterFix,
          onRenameChanged: (v) => setState(() => _batchRenameAfterFix = v ?? false),
          cameraCtrl: _batchCameraNameCtrl,
        ),

        const SizedBox(height: 24),
        _actionButton(
          label: 'Run Batch Fix',
          icon: Icons.auto_fix_high_rounded,
          enabled: _canBatchFix,
          isProcessing: _isBatchProcessing,
          onPressed: _runBatch,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            setState(() {
              _batchOriginalFolder = null;
              _batchEncodedFolder  = null;
              _batchOutputFolder   = null;
              _logs.clear();
            });
            _log('Cleared.', LogLevel.system);
          },
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF555555)),
          child: const Text('Clear All', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Folder drop zone ──────────────────────────────────────────────────────
  Widget _folderDropZone({
    required String hint,
    required String? selectedPath,
    required bool isDragging,
    required IconData icon,
    required VoidCallback onBrowse,
    required VoidCallback onDragEnter,
    required VoidCallback onDragExit,
    required ValueChanged<String> onDropped,
    bool clearable = false,
    VoidCallback? onClear,
  }) {
    final hasFolder = selectedPath != null;
    return DropTarget(
      onDragEntered: (_) => onDragEnter(),
      onDragExited:  (_) => onDragExit(),
      onDragDone: (detail) {
        if (detail.files.isEmpty) return;
        final dropped  = detail.files.first.path;
        final type     = FileSystemEntity.typeSync(dropped);
        final resolved = type == FileSystemEntityType.directory
            ? dropped
            : p.dirname(dropped);
        onDropped(resolved);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDragging
              ? const Color(0xFFFF6B35).withValues(alpha: 0.08)
              : hasFolder ? const Color(0xFF1E1E1E) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDragging
                ? const Color(0xFFFF6B35)
                : hasFolder ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
            width: isDragging ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onBrowse,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: hasFolder
                      ? const Color(0xFFFF6B35).withValues(alpha: 0.15)
                      : const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon,
                    color: hasFolder ? const Color(0xFFFF6B35) : const Color(0xFF666666),
                    size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasFolder ? _trunc(selectedPath) : hint,
                    style: TextStyle(
                      color: hasFolder ? Colors.white : const Color(0xFF555555),
                      fontSize: 12,
                      fontWeight: hasFolder ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hasFolder)
                    const Text('Drop folder here or click to browse',
                        style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 10)),
                ],
              )),
              const SizedBox(width: 8),
              if (hasFolder && clearable && onClear != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF555555)),
                  ),
                )
              else if (hasFolder)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 16)
              else
                const Icon(Icons.folder_open_rounded, color: Color(0xFF444444), size: 16),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Shared options section ────────────────────────────────────────────────
  Widget _optionsSection({
    required bool fixFileDates,
    required ValueChanged<bool?> onFixFileDatesChanged,
    required bool renameAfterFix,
    required ValueChanged<bool?> onRenameChanged,
    required TextEditingController cameraCtrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252525)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('OPTIONS'),
        const SizedBox(height: 12),
        Row(children: [
          Checkbox(value: fixFileDates, onChanged: onFixFileDatesChanged),
          const SizedBox(width: 6),
          const Expanded(child: Text('Fix file system timestamps',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13))),
          const Tooltip(
            message: 'Sets the file\'s Modified & Created date on disk\n'
                'to match the embedded CreateDate tag.\n'
                'Required for Few Gallery Apps or\n'
                'any other apps that read file dates instead of EXIF.',
            preferBelow: false,
            child: Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF555555)),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Checkbox(value: renameAfterFix, onChanged: onRenameChanged),
          const SizedBox(width: 6),
          const Expanded(child: Text('Rename after Fixing',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13))),
        ]),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: renameAfterFix
              ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('RENAME TEMPLATE'),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Text(
                    cameraCtrl.text.trim().isEmpty ? '[date]' : '[date] -',
                    style: _mono(color: const Color(0xFF555555)),
                  ),
                ),
                Expanded(child: TextField(
                  controller: cameraCtrl,
                  style: _mono(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'a6700',
                    hintStyle: _mono(color: const Color(0xFF444444)),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFF333333)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFF333333)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFFF6B35), width: 1.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              Text(
                cameraCtrl.text.trim().isEmpty
                    ? 'Preview: 2024-03-15_14-30-00.mp4'
                    : 'Preview: 2024-03-15_14-30-00 - ${cameraCtrl.text.trim()}.mp4',
                style: _mono(color: const Color(0xFF555555), fontSize: 10),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Shared action button ──────────────────────────────────────────────────
  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required bool isProcessing,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFFFF6B35) : const Color(0xFF1E1E1E),
          foregroundColor: enabled ? Colors.white : const Color(0xFF3A3A3A),
          disabledBackgroundColor: const Color(0xFF1E1E1E),
          disabledForegroundColor: const Color(0xFF3A3A3A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: isProcessing
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: _inter(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2)),
              ]),
      ),
    );
  }

  // ── Console panel ─────────────────────────────────────────────────────────
  Widget _consolePanel() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _label('CONSOLE OUTPUT'),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _logs.clear()),
            icon: const Icon(Icons.delete_sweep_rounded, size: 14),
            label: const Text('Clear', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF555555),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: ConsoleOutput(entries: _logs, scrollController: _scrollCtrl)),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.drag_indicator_rounded, size: 12, color: Color(0xFF3A3A3A)),
          const SizedBox(width: 6),
          const Text('Drag & drop files or folders onto the input areas, or click to browse.',
              style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 11)),
          const Spacer(),
          Text('${_logs.length} entries',
              style: const TextStyle(color: Color(0xFF2A2A2A), fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _footer() {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        height: 48,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Developed by Meghana',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 11)),
          const SizedBox(height: 5),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openUrl('https://github.com/im-meghana'),
              child: const Tooltip(
                message: 'github.com/im-meghana',
                child: FaIcon(FontAwesomeIcons.github, size: 16, color: Color(0xFFAAAAAA)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Open URL (Windows uses cmd /c start) ──────────────────────────────────
  void _openUrl(String url) {
    if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    } else if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', url], runInShell: false);
    }
  }

  // ── Shared label ──────────────────────────────────────────────────────────
  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFF555555), fontSize: 10,
          letterSpacing: 1.2, fontWeight: FontWeight.w700));
}
