import '../entities/enums.dart';

/// Suggests a title and type for captured text. Suggestions remain editable,
/// and suggestion failures must not block saving.
class CaptureSuggestion {
  const CaptureSuggestion({
    required this.title,
    required this.type,
    this.url,
    this.titleIsPlaceholder = false,
  });

  final String title;
  final SavedItemType type;
  final String? url;

  /// True when the title is only a placeholder ("New item — Oct 26, 2026").
  final bool titleIsPlaceholder;
}

class CaptureSuggester {
  const CaptureSuggester._();

  static final RegExp _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String placeholderTitle(DateTime now) =>
      'New item — ${_months[now.month - 1]} ${now.day}, ${now.year}';

  /// [fromShare] = true membuat teks non-tautan dianggap "pesan" (salinan chat),
  /// bukan "catatan".
  static CaptureSuggestion suggest(
    String rawText, {
    String? subject,
    bool fromShare = false,
    DateTime? now,
  }) {
    final text = rawText.trim();
    final cleanSubject = _clean(subject);
    final raw = _url.allMatches(text).map((m) => m.group(0)!).toList();
    final urls = raw.map(_trimUrl).toList();
    final firstUrl = urls.isEmpty ? null : urls.first;

    // Yang dibuang dari teks adalah kecocokan mentah (termasuk tanda baca
    // penutup), supaya sisa seperti ")." tidak ikut menjadi judul.
    var rest = text;
    for (final r in raw) {
      rest = rest.replaceAll(r, ' ');
    }
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (firstUrl != null && rest.length <= 200) {
      final title = cleanSubject ??
          (rest.isNotEmpty ? _firstLine(rest) : _hostOf(firstUrl));
      return CaptureSuggestion(
        title: _limit(title),
        type: SavedItemType.link,
        url: firstUrl,
      );
    }

    final type = firstUrl != null || fromShare
        ? SavedItemType.message
        : SavedItemType.note;
    final candidate = cleanSubject ?? _firstLine(text);
    if (candidate.isEmpty) {
      return CaptureSuggestion(
        title: placeholderTitle(now ?? DateTime.now()),
        type: type,
        url: firstUrl,
        titleIsPlaceholder: true,
      );
    }
    return CaptureSuggestion(
      title: _limit(candidate),
      type: type,
      url: firstUrl,
    );
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _firstLine(String s) {
    for (final line in s.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String _limit(String s) => s.length <= 80 ? s : '${s.substring(0, 77)}...';

  /// Membuang tanda baca penutup yang biasanya bukan bagian dari URL.
  static String _trimUrl(String u) => u.replaceAll(RegExp(r'[),.;:!?]+$'), '');

  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.isEmpty ? url : host.replaceFirst(RegExp(r'^www\.'), '');
  }
}
