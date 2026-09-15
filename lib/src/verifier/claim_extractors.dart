/// Pure text-mining helpers that pull "claims" out of an AI-generated
/// SKILL.md draft so `DraftVerifier` can cross-check each one against
/// the project's `EvidenceBundle`.
///
/// A "claim" here is a token that asserts something about the target
/// project (e.g. "lib/features/auth/auth_bloc.dart exists",
/// "AuthBloc is a class in this project", "files follow *_cubit.dart").
/// Extractors return the token along with line context so the verifier
/// can annotate or strip offending lines later.
library;

/// A single claim extracted from draft text.
class TextClaim {
  /// Creates a [TextClaim].
  const TextClaim({
    required this.value,
    required this.line,
    required this.lineNumber,
  });

  /// The exact claim token as it appears in the draft
  /// (e.g. `lib/features/auth/auth_bloc.dart`, `AuthBloc`).
  final String value;

  /// Full text of the line that contains the claim. Useful for
  /// rendering violations back to the user.
  final String line;

  /// 1-based line number where the claim appears.
  final int lineNumber;
}

/// Extracts every `lib/.../foo.dart` style path reference. The
/// character preceding the `lib/` prefix must not be a word, dot, or
/// slash, so we skip matches inside URLs (`.../blob/main/lib/foo.dart`)
/// and compound identifiers (`mylib/foo.dart`).
List<TextClaim> extractFilePathClaims(String text) {
  final pattern = RegExp(r'(?:^|[^\w./])(lib/[\w./-]+\.dart)');
  final claims = <TextClaim>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    for (final m in pattern.allMatches(lines[i])) {
      claims.add(
        TextClaim(value: m.group(1)!, line: lines[i], lineNumber: i + 1),
      );
    }
  }
  return claims;
}

/// Extracts `*_foo.dart` glob-style file-name patterns.
List<TextClaim> extractGlobPatternClaims(String text) {
  final pattern = RegExp(r'(\*_[A-Za-z0-9_-]+\.dart)');
  final claims = <TextClaim>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    for (final m in pattern.allMatches(lines[i])) {
      claims.add(
        TextClaim(value: m.group(1)!, line: lines[i], lineNumber: i + 1),
      );
    }
  }
  return claims;
}

/// Identifier suffixes that unambiguously imply a project-owned class
/// (as opposed to a Flutter/Dart framework type). We check every
/// PascalCase token ending with one of these against the evidence
/// bundle's `allClassNames`.
const projectClassSuffixes = <String>[
  // Order matters: longer suffixes must appear before their shorter
  // prefixes (e.g. `RepositoryImpl` before `Repository`) so the
  // alternation picks the most specific match first.
  'RepositoryImpl',
  'RemoteDataSource',
  'LocalDataSource',
  'DataSource',
  'Repository',
  'UseCase',
  'Notifier',
  'Controller',
  'Service',
  'Entity',
  'Model',
  'State',
  'Event',
  'Bloc',
  'Cubit',
  'Dto',
];

/// Framework / package types that end in a project-like suffix but
/// must NOT be flagged when the user's `lib/` doesn't declare them.
const frameworkClassWhitelist = <String>{
  // flutter
  'ValueNotifier', 'ChangeNotifier',
  // riverpod
  'StateNotifier', 'AsyncNotifier', 'StreamNotifier',
  'FamilyNotifier', 'AutoDisposeNotifier', 'AutoDisposeAsyncNotifier',
  'AutoDisposeStreamNotifier', 'AutoDisposeFamilyNotifier',
  // bloc (base classes — caught because regex allows the anchor itself
  // as a match target in some edge cases)
  'HydratedBloc', 'HydratedCubit', 'ReplayBloc', 'ReplayCubit',
  // misc
  'GetxController',
};

/// Extracts PascalCase class-name tokens that end in a project-specific
/// suffix (e.g. `AuthBloc`, `LoginCubit`, `UserRepositoryImpl`).
/// Framework types like `StateNotifier` are whitelisted.
List<TextClaim> extractClassNameClaims(String text) {
  final suffixUnion = projectClassSuffixes.join('|');
  final pattern = RegExp('\\b([A-Z][A-Za-z0-9]+(?:$suffixUnion))\\b');
  final claims = <TextClaim>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    for (final m in pattern.allMatches(lines[i])) {
      final value = m.group(1)!;
      if (frameworkClassWhitelist.contains(value)) continue;
      claims.add(TextClaim(value: value, line: lines[i], lineNumber: i + 1));
    }
  }
  return claims;
}

/// Natural-language patterns that assert DI registration happens
/// inside each feature directory. The verifier only flags these when
/// the evidence bundle shows `di.perFeature == false`.
final _diPerFeaturePatterns = <RegExp>[
  RegExp(
    r'per[- ]feature\s+(?:DI|dependency\s+injection|injection)',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:DI|dependency\s+injection|injection)\s+(?:is\s+)?'
    r'(?:done|registered|performed|organized|defined)\s+per[- ]feature',
    caseSensitive: false,
  ),
  RegExp(
    r'each\s+feature\s+(?:has|registers|owns|defines)\s+'
    r'(?:its\s+own\s+)?(?:DI|injection|dependencies|service\s+locator)',
    caseSensitive: false,
  ),
  RegExp(
    r'feature[- ]local\s+(?:DI|injection|registration)',
    caseSensitive: false,
  ),
];

/// Words that turn a per-feature DI phrase into a statement that the
/// project does *not* use per-feature DI.
///
/// Without these, accurate guidance was flagged as a hallucination:
/// "DI is centralized … rather than per-feature injection files" and
/// "Don't create a per-feature DI file" both contain the phrase the
/// patterns above look for while asserting the opposite. Penalising
/// them taught writers to avoid stating the true thing, which is worse
/// than the occasional missed claim.
final _diNegationCues = RegExp(
  r'(?:\bno\b|\bnot\b|\bnever\b|\bavoid(?:s|ed)?\b|\bwithout\b'
  r'|\brather\s+than\b|\binstead\s+of\b|\bdo\s+not\b'
  r"|\bdon'?t\b|\bdoesn'?t\b|\bisn'?t\b|\baren'?t\b"
  r'|\bnone\s+of\b|\bno\s+longer\b)',
  caseSensitive: false,
);

/// Returns the clause of [line] containing [index].
///
/// Suppression is scoped to one clause so a negation in an earlier
/// sentence cannot smuggle a real claim past the verifier.
String _clauseContaining(String line, int index) {
  const separators = ['. ', '; ', ': ', '! ', '? ', ' — ', ' – '];

  var start = 0;
  for (final sep in separators) {
    final i = line.lastIndexOf(sep, index);
    if (i != -1 && i + sep.length > start && i + sep.length <= index) {
      start = i + sep.length;
    }
  }

  var end = line.length;
  for (final sep in separators) {
    final i = line.indexOf(sep, index);
    if (i != -1 && i < end) end = i;
  }

  return line.substring(start, end);
}

/// Extracts phrases asserting DI is per-feature.
///
/// Phrases inside a negated clause are skipped — see [_diNegationCues].
List<TextClaim> extractDiPerFeatureClaims(String text) {
  final claims = <TextClaim>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final pat in _diPerFeaturePatterns) {
      final m = pat.firstMatch(line);
      if (m == null) continue;
      if (_diNegationCues.hasMatch(_clauseContaining(line, m.start))) {
        break;
      }
      claims.add(TextClaim(value: m.group(0)!, line: line, lineNumber: i + 1));
      break;
    }
  }
  return claims;
}
