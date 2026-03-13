import 'dart:io';

class ExifToolService {
  static String? _resolvedPath;

  /// Call this before re-probing so a stale cached path is not reused.
  static void clearCache() => _resolvedPath = null;

  // ── Candidate paths per platform ─────────────────────────────────────────
  // GUI apps on macOS/Linux don't inherit the full shell PATH, so we probe
  // known install locations directly rather than relying on PATH lookup.

  static List<String> get _candidates {
    if (Platform.isMacOS) {
      return [
        '/opt/homebrew/bin/exiftool',  // Apple Silicon (brew)
        '/usr/local/bin/exiftool',     // Intel Mac (brew / manual)
        '/usr/bin/exiftool',           // rare system install
      ];
    }
    if (Platform.isLinux) {
      return [
        '/usr/bin/exiftool',           // apt / dnf / pacman default
        '/usr/local/bin/exiftool',     // manual install
        '/snap/bin/exiftool',          // snap package
        '/home/linuxbrew/.linuxbrew/bin/exiftool', // Linuxbrew
      ];
    }
    if (Platform.isWindows) {
      return [
        r'C:\Windows\exiftool.exe',                        // common manual drop
        r'C:\Windows\System32\exiftool.exe',               // system32
        r'C:\Program Files\ExifTool\exiftool.exe',         // MSI installer
        r'C:\Program Files (x86)\ExifTool\exiftool.exe',   // 32-bit MSI
        r'C:\ProgramData\chocolatey\bin\exiftool.exe',     // choco
        // Scoop: expand %USERPROFILE% at runtime
        '${Platform.environment['USERPROFILE'] ?? ''}'
            r'\scoop\shims\exiftool.exe',
      ];
    }
    return [];
  }

  // ── Find executable ───────────────────────────────────────────────────────
  static Future<String?> _findExecutable() async {
    if (_resolvedPath != null) return _resolvedPath;

    // 1. Probe known absolute paths
    for (final candidate in _candidates) {
      if (candidate.isEmpty) continue;
      try {
        if (!File(candidate).existsSync()) continue;
        final result = await Process.run(candidate, ['-ver'], runInShell: false);
        if (result.exitCode == 0) {
          _resolvedPath = candidate;
          return candidate;
        }
      } catch (_) {
        continue;
      }
    }

    // 2. Shell fallback — works when the tool is on PATH
    try {
      if (Platform.isWindows) {
        // 'where' is the Windows equivalent of 'which'
        final result = await Process.run('where', ['exiftool.exe'], runInShell: true);
        final found = result.stdout.toString().trim().split(RegExp(r'\r?\n')).first.trim();
        if (result.exitCode == 0 && found.isNotEmpty) {
          final verify = await Process.run(found, ['-ver'], runInShell: false);
          if (verify.exitCode == 0) {
            _resolvedPath = found;
            return found;
          }
        }
      } else {
        // macOS / Linux — use sh -c to pick up user PATH
        final result = await Process.run(
          '/bin/sh', ['-c', 'command -v exiftool'],
          runInShell: false,
        );
        final found = result.stdout.toString().trim();
        if (result.exitCode == 0 && found.isNotEmpty) {
          _resolvedPath = found;
          return found;
        }
      }
    } catch (_) {}

    return null;
  }

  // ── Public API ────────────────────────────────────────────────────────────
  static Future<bool>   isAvailable()  async => (await _findExecutable()) != null;
  static Future<String> resolvedPath() async => (await _findExecutable()) ?? 'not found';

  static Future<String> getVersion() async {
    final exe = await _findExecutable();
    if (exe == null) return 'unknown';
    try {
      final result = await Process.run(exe, ['-ver']);
      return result.stdout.toString().trim();
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<ProcessResult> fixMetadata({
    required String originalPath,
    required String encodedPath,
  }) async {
    final exe = await _findExecutable();
    if (exe == null) throw Exception('exiftool not found');
    return Process.run(exe, [
      '-api', 'QuickTimeUTC=1',
      '-tagsFromFile', originalPath,
      '-AllDates<CreationDateValue',
      '-QuickTime:CreationDate<CreationDateValue',
      '-XMP:DateTimeOriginal<CreationDateValue',
      '-Model<DeviceModelName',
      '-LensModel<LensModelName',
      '-Make<DeviceManufacturer',
      '-overwrite_original',
      encodedPath,
    ]);
  }

  /// Sets the file system timestamps (Modified + Created) to match
  /// the embedded CreateDate tag. This ensures gallery apps that read
  /// file dates (instead of EXIF) also show the correct date.
  ///
  /// Note: -FileCreateDate is not reliably settable on Windows via ExifTool,
  /// so it is intentionally omitted on that platform.
  static Future<ProcessResult> fixFileDates({
    required String filePath,
  }) async {
    final exe = await _findExecutable();
    if (exe == null) throw Exception('exiftool not found');
    return Process.run(exe, [
      '-api', 'QuickTimeUTC=1',
      '-overwrite_original',
      '-FileModifyDate<CreateDate',
      // FileCreateDate (creation time) can only be set on macOS/Linux.
      // On Windows, ExifTool cannot reliably write NTFS creation time.
      if (!Platform.isWindows) '-FileCreateDate<CreateDate',
      filePath,
    ]);
  }

  static Future<ProcessResult> renameFile({
    required String encodedPath,
    required String userText,
  }) async {
    final exe = await _findExecutable();
    if (exe == null) throw Exception('exiftool not found');
    // Sanitise userText: strip characters that would break the ExifTool
    // filename template on any platform (backslash, slash, colon, quotes,
    // angle brackets, pipe, asterisk, question mark).
    final safe = userText.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    final template = safe.isEmpty
        ? r'-filename<${CreateDate}.%e'
        : r'-filename<${CreateDate} - ' '$safe.%e';
    return Process.run(exe, [
      '-d', '%Y-%m-%d_%H-%M-%S',
      template,
      encodedPath,
    ]);
  }

  /// Returns platform-specific install instructions as a list of steps.
  static List<String> installInstructions() {
    if (Platform.isMacOS) {
      return [
        'brew install exiftool',
      ];
    }
    if (Platform.isWindows) {
      return [
        'Option A - winget:',
        '  winget install -e --id OliverBetz.ExifTool',
        '',
        'Option B - Chocolatey:',
        '  choco install exiftool',
        '',
        'Option C - Scoop:',
        '  scoop install exiftool',
        '',
        'Option D - Manual:',
        '  1. Download from https://exiftool.org',
        '  2. Rename exiftool(-k).exe to exiftool.exe',
        r'  3. Move to C:\Windows\',
      ];
    }
    if (Platform.isLinux) {
      return [
        'Ubuntu / Debian:',
        '  sudo apt install libimage-exiftool-perl',
        '',
        'Fedora / RHEL:',
        '  sudo dnf install perl-Image-ExifTool',
        '',
        'Arch:',
        '  sudo pacman -S perl-image-exiftool',
        '',
        'Snap:',
        '  sudo snap install exiftool',
      ];
    }
    return ['Install exiftool from https://exiftool.org'];
  }

  /// Returns the paths that were checked, for diagnostic display.
  static List<String> checkedPaths() => _candidates;
}
