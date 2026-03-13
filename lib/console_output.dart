import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LogLevel { info, success, warning, error, system }

class LogEntry {
  final String message;
  final LogLevel level;

  LogEntry({required this.message, required this.level});
}

// Monospace style using system fonts only - no network calls.
TextStyle _mono({
  double fontSize = 11,
  Color color = Colors.white,
  FontWeight fontWeight = FontWeight.normal,
  double letterSpacing = 0,
  double height = 1.5,
}) =>
    TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['SF Mono', 'Menlo', 'Monaco', 'Courier New'],
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );

class ConsoleOutput extends StatelessWidget {
  final List<LogEntry> entries;
  final ScrollController scrollController;

  const ConsoleOutput({
    super.key,
    required this.entries,
    required this.scrollController,
  });

  Color _colorForLevel(LogLevel level) => switch (level) {
        LogLevel.info => const Color(0xFFAAAAAA),
        LogLevel.success => const Color(0xFF4CAF50),
        LogLevel.warning => const Color(0xFFFFB74D),
        LogLevel.error => const Color(0xFFEF5350),
        LogLevel.system => const Color(0xFF64B5F6),
      };

  String _prefixForLevel(LogLevel level) => switch (level) {
        LogLevel.info => '›',
        LogLevel.success => '✓',
        LogLevel.warning => '⚠',
        LogLevel.error => '✕',
        LogLevel.system => '#',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Console output will appear here…',
                      style: _mono(color: const Color(0xFF3A3A3A)),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _prefixForLevel(e.level),
                              style: _mono(color: _colorForLevel(e.level)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.message,
                                style: _mono(color: _colorForLevel(e.level)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: Row(
        children: [
          _dot(const Color(0xFFEF5350)),
          const SizedBox(width: 5),
          _dot(const Color(0xFFFFB74D)),
          const SizedBox(width: 5),
          _dot(const Color(0xFF4CAF50)),
          const SizedBox(width: 10),
          Text(
            'CONSOLE',
            style: _mono(
              color: const Color(0xFF444444),
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (entries.isNotEmpty)
            GestureDetector(
              onTap: () {
                final text = entries
                    .map((e) => '${_prefixForLevel(e.level)} ${e.message}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: text));
              },
              child: Text(
                'COPY',
                style: _mono(
                  color: const Color(0xFF555555),
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
