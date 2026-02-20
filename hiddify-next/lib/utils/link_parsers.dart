import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:hiddify/features/profile/data/profile_parser.dart';
import 'package:hiddify/features/profile/data/profile_repository.dart';
import 'package:hiddify/singbox/model/singbox_proxy_type.dart';
import 'package:hiddify/utils/validators.dart';

typedef ProfileLink = ({String url, String name});

// TODO: test and improve
abstract class LinkParser {
  static final _inlineLinkRegex = RegExp(
    r'''(?:https?|ftp|hiddify|clashmeta?|sing-box):\/\/[^\s<>"']+''',
    caseSensitive: false,
  );
  static final _markdownLinkRegex = RegExp(r'\[[^\]]+\]\(([^)]+)\)');
  static const _telegramHosts = {
    't.me',
    'telegram.me',
    'telegram.dog',
    'telegram.org',
    'www.t.me',
    'www.telegram.me',
    'www.telegram.dog',
    'www.telegram.org',
  };

  static String generateSubShareLink(String url, [String? name]) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final modifiedUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path,
      query: uri.query,
      fragment: name ?? uri.fragment,
    );
    // return 'hiddify://import/$modifiedUri';
    return '$modifiedUri';
  }

  // protocols schemas
  static const protocols = {'clash', 'clashmeta', 'sing-box', 'hiddify'};

  static ProfileLink? parse(String link) {
    return simple(link) ?? deep(link);
  }

  /// Parse a user-provided text that may include extra words, markdown,
  /// telegram wrappers, or encoded links.
  static ProfileLink? parseFromText(String rawInput) {
    final candidates = parseCandidatesFromText(rawInput);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Returns parsed links ordered by priority:
  /// 1) deep links, 2) direct non-telegram URLs, 3) telegram wrappers.
  static List<ProfileLink> parseCandidatesFromText(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) return const [];

    final deepLinks = <ProfileLink>[];
    final directLinks = <ProfileLink>[];
    final telegramLinks = <ProfileLink>[];
    final seen = <String>{};

    void addCandidate(ProfileLink? link, {bool isDeepLink = false}) {
      if (link == null) return;
      final key = '${link.url}#${link.name}';
      if (!seen.add(key)) return;
      final isTelegram = _isTelegramUrl(link.url);
      if (isDeepLink) {
        deepLinks.add(link);
      } else if (isTelegram) {
        telegramLinks.add(link);
      } else {
        directLinks.add(link);
      }
    }

    final sources = _extractCandidateLinks(input);
    for (final source in sources) {
      final normalized = _trimLink(source);
      if (normalized.isEmpty) continue;

      addCandidate(deep(normalized), isDeepLink: true);
      addCandidate(simple(normalized));

      for (final embedded in _extractEmbeddedCandidates(normalized)) {
        final candidate = _trimLink(embedded);
        if (candidate.isEmpty) continue;
        addCandidate(deep(candidate), isDeepLink: true);
        addCandidate(simple(candidate));
      }
    }

    return [...deepLinks, ...directLinks, ...telegramLinks];
  }

  static ProfileLink? simple(String link) {
    if (!isUrl(link)) return null;
    final uri = Uri.parse(link.trim());
    return (
      url: uri.toString(),
      name: uri.queryParameters['name'] ?? '',
    );
  }

  static ({String content, String name})? protocol(String content) {
    final normalContent = safeDecodeBase64(content);
    final lines = normalContent.split('\n');
    String? name;
    for (final line in lines) {
      final uri = Uri.tryParse(line);
      if (uri == null) continue;
      final fragment = uri.hasFragment ? Uri.decodeComponent(uri.fragment.split("&&detour")[0]) : null;
      name ??= switch (uri.scheme) {
        'ss' => fragment ?? ProxyType.shadowsocks.label,
        'ssconf' => fragment ?? ProxyType.shadowsocks.label,
        'vmess' => ProxyType.vmess.label,
        'vless' => fragment ?? ProxyType.vless.label,
        'trojan' => fragment ?? ProxyType.trojan.label,
        'tuic' => fragment ?? ProxyType.tuic.label,
        'hy2' || 'hysteria2' => fragment ?? ProxyType.hysteria2.label,
        'hy' || 'hysteria' => fragment ?? ProxyType.hysteria.label,
        'ssh' => fragment ?? ProxyType.ssh.label,
        'wg' => fragment ?? ProxyType.wireguard.label,
        'warp' => fragment ?? ProxyType.warp.label,
        _ => null,
      };
    }
    final headers = ProfileRepositoryImpl.parseHeadersFromContent(content);
    final subinfo = ProfileParser.parse("", headers);

    if (subinfo.name.isNotNullOrEmpty && subinfo.name != "Remote Profile") {
      name = subinfo.name;
    }

    return (content: normalContent, name: name ?? ProxyType.unknown.label);
  }

  static ProfileLink? deep(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    final queryParams = uri.queryParameters;
    switch (uri.scheme) {
      case 'clash' || 'clashmeta' when uri.authority == 'install-config':
        if (uri.authority != 'install-config' || !queryParams.containsKey('url')) return null;
        return (url: queryParams['url']!, name: queryParams['name'] ?? '');
      case 'sing-box':
        if (uri.authority != 'import-remote-profile' || !queryParams.containsKey('url')) return null;
        return (url: queryParams['url']!, name: queryParams['name'] ?? '');
      case 'hiddify':
        if (uri.authority == "import") {
          final rawPath = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
          final decodedPath = _decodeRecursively(rawPath);
          final hasQueryInPath = decodedPath.contains('?');
          final fullUrl = uri.hasQuery
              ? '$decodedPath${hasQueryInPath ? '&' : '?'}${uri.query}'
              : decodedPath;
          return (url: fullUrl, name: uri.fragment);
        }
        //for backward compatibility
        if ((uri.authority != 'install-config' && uri.authority != 'install-sub') || !queryParams.containsKey('url')) return null;
        return (url: queryParams['url']!, name: queryParams['name'] ?? '');
      default:
        return null;
    }
  }

  static List<String> _extractCandidateLinks(String input) {
    final candidates = <String>[input];

    for (final match in _markdownLinkRegex.allMatches(input)) {
      final value = match.group(1);
      if (value != null && value.isNotEmpty) {
        candidates.add(value);
      }
    }

    for (final match in _inlineLinkRegex.allMatches(input)) {
      final value = match.group(0);
      if (value != null && value.isNotEmpty) {
        candidates.add(value);
      }
    }

    return candidates;
  }

  static Iterable<String> _extractEmbeddedCandidates(String input) sync* {
    final uri = Uri.tryParse(input);
    if (uri == null) return;

    for (final values in uri.queryParametersAll.values) {
      for (final value in values) {
        if (value.isEmpty) continue;
        yield value;
        final decoded = _decodeRecursively(value);
        if (decoded != value) yield decoded;
      }
    }

    if (uri.fragment.isNotEmpty) {
      yield uri.fragment;
      final decoded = _decodeRecursively(uri.fragment);
      if (decoded != uri.fragment) yield decoded;
    }

    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    if (path.contains('%')) {
      final decoded = _decodeRecursively(path);
      if (decoded != path) yield decoded;
    }
  }

  static bool _isTelegramUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return _telegramHosts.contains(uri.host.toLowerCase());
  }

  static String _trimLink(String link) {
    var value = link.trim();
    if (value.isEmpty) return value;

    const leading = '<("\'[';
    while (value.isNotEmpty && leading.contains(value[0])) {
      value = value.substring(1);
    }

    const trailing = '>),.;:!?"\'`]';
    while (value.isNotEmpty && trailing.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }

    return value.trim();
  }

  static String _decodeRecursively(String value, {int maxDepth = 3}) {
    var current = value;
    for (var i = 0; i < maxDepth; i++) {
      try {
        final decoded = Uri.decodeComponent(current);
        if (decoded == current) {
          return decoded;
        }
        current = decoded;
      } catch (_) {
        return current;
      }
    }
    return current;
  }
}

String safeDecodeBase64(String str) {
  try {
    return utf8.decode(base64Decode(str));
  } catch (e) {
    return str;
  }
}
