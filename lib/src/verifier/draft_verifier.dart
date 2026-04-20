import '../models/evidence_bundle.dart';
import 'claim_extractors.dart';

/// What the verifier does with unsupported claims it finds.
enum VerifierMode {
  /// Remove the offending line outright. Loses context but guarantees
  /// the final draft is claim-clean.
  strip,

  /// Keep the line but append an `<!-- [UNVERIFIED: ...] -->` marker
  /// so the human reviewer can see what the verifier flagged.
  annotate,

  /// Return the draft unchanged; the caller must inspect
  /// `VerificationResult.violations` and throw or abort generation.
  fatal,
}

/// The category of a single claim-vs-evidence mismatch.
enum ViolationKind {
  /// A `lib/**/*.dart` path in the draft that isn't present in the
  /// evidence bundle's file manifest.
  unknownFilePath,

  /// A PascalCase class-name token with a project-specific suffix
  /// (e.g. `AuthBloc`) that isn't declared anywhere under lib/.
  unknownClassName,

  /// A `*_foo.dart` glob pattern that doesn't match any file in the
  /// project.
  unknownGlobPattern,

  /// A prose claim that DI is registered per-feature, contradicted by
  /// evidence of centralized DI.
  falseDiPerFeatureClaim,
}

/// One mismatch between a draft claim and the evidence bundle.
class Violation {
  /// Creates a [Violation].
  const Violation({
    required this.kind,
    required this.claim,
    required this.reason,
    required this.line,
    required this.lineNumber,
  });

  /// The category of mismatch.
  final ViolationKind kind;

  /// The exact claim token as it appears in the draft.
  final String claim;

  /// Human-readable explanation of why evidence doesn't support this
  /// claim. Suitable for logging or annotation markers.
  final String reason;

  /// Full text of the offending line (useful for error reports).
  final String line;

  /// 1-based line number within the draft.
  final int lineNumber;
}

/// Output of [DraftVerifier.verify].
class VerificationResult {
  /// Creates a [VerificationResult].
  const VerificationResult({required this.output, required this.violations});

  /// The (possibly transformed) draft. In `strip`/`annotate` modes
  /// this differs from the input; in `fatal` mode it equals the
  /// input verbatim.
  final String output;

  /// All mismatches discovered during verification, in line order.
  final List<Violation> violations;

  /// Convenience — `true` iff any violations were recorded.
  bool get hasViolations => violations.isNotEmpty;
}

/// Cross-checks an AI-generated SKILL.md draft against the project's
/// grounded evidence bundle and transforms the draft per [mode].
class DraftVerifier {
  /// Creates a [DraftVerifier].
  const DraftVerifier({
    required this.evidence,
    this.mode = VerifierMode.annotate,
  });

  /// The project's grounded evidence — treated as the source of truth.
  final EvidenceBundle evidence;

  /// How to handle violations (see [VerifierMode]).
  final VerifierMode mode;

  /// Glob patterns that are universally valid Dart project conventions
  /// (tests, mocks, codegen output) and therefore not flagged even
  /// when no matching files exist in `lib/`.
  static const _globPatternWhitelist = <String>{
    '*_test.dart',
    '*_mock.dart',
    '*_mocks.dart',
    '*.g.dart',
    '*.freezed.dart',
    '*.gr.dart',
    '*.config.dart',
  };

  /// Runs every claim extractor against [draft], records mismatches,
  /// and returns the transformed draft plus the full violation list.
  VerificationResult verify(String draft) {
    final violations =
        <Violation>[
          ..._verifyFilePaths(draft),
          ..._verifyGlobPatterns(draft),
          ..._verifyClassNames(draft),
          ..._verifyDiPerFeatureClaims(draft),
        ]..sort((a, b) {
          final byLine = a.lineNumber.compareTo(b.lineNumber);
          return byLine != 0 ? byLine : a.claim.compareTo(b.claim);
        });

    final output = switch (mode) {
      VerifierMode.fatal => draft,
      VerifierMode.strip => _stripLines(draft, violations),
      VerifierMode.annotate => _annotateLines(draft, violations),
    };

    return VerificationResult(output: output, violations: violations);
  }

  List<Violation> _verifyFilePaths(String draft) {
    final known = evidence.fileManifest.allFilePaths.toSet();
    return [
      for (final c in extractFilePathClaims(draft))
        if (!known.contains(c.value))
          Violation(
            kind: ViolationKind.unknownFilePath,
            claim: c.value,
            reason: 'path not present in lib/ manifest',
            line: c.line,
            lineNumber: c.lineNumber,
          ),
    ];
  }

  List<Violation> _verifyGlobPatterns(String draft) {
    final known = evidence.knownFilePatterns.toSet();
    return [
      for (final c in extractGlobPatternClaims(draft))
        if (!_globPatternWhitelist.contains(c.value) &&
            !known.contains(c.value))
          Violation(
            kind: ViolationKind.unknownGlobPattern,
            claim: c.value,
            reason: 'no lib/ files match this pattern',
            line: c.line,
            lineNumber: c.lineNumber,
          ),
    ];
  }

  List<Violation> _verifyClassNames(String draft) {
    final known = evidence.fileManifest.allClassNames.toSet();
    return [
      for (final c in extractClassNameClaims(draft))
        if (!known.contains(c.value))
          Violation(
            kind: ViolationKind.unknownClassName,
            claim: c.value,
            reason: 'class not declared anywhere under lib/',
            line: c.line,
            lineNumber: c.lineNumber,
          ),
    ];
  }

  List<Violation> _verifyDiPerFeatureClaims(String draft) {
    if (evidence.di.perFeature) return const [];
    return [
      for (final c in extractDiPerFeatureClaims(draft))
        Violation(
          kind: ViolationKind.falseDiPerFeatureClaim,
          claim: c.value,
          reason: 'evidence shows DI is centralized, not per-feature',
          line: c.line,
          lineNumber: c.lineNumber,
        ),
    ];
  }

  String _annotateLines(String draft, List<Violation> violations) {
    if (violations.isEmpty) return draft;
    final byLine = <int, List<Violation>>{};
    for (final v in violations) {
      byLine.putIfAbsent(v.lineNumber, () => []).add(v);
    }
    final lines = draft.split('\n');
    final buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      buf.write(lines[i]);
      final vs = byLine[i + 1];
      if (vs != null) {
        final claims = vs.map((v) => v.claim).toSet().join(', ');
        buf.write(' <!-- [UNVERIFIED: $claims] -->');
      }
      if (i < lines.length - 1) buf.write('\n');
    }
    return buf.toString();
  }

  String _stripLines(String draft, List<Violation> violations) {
    if (violations.isEmpty) return draft;
    final violatingLines = violations.map((v) => v.lineNumber).toSet();
    final lines = draft.split('\n');
    final kept = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!violatingLines.contains(i + 1)) kept.add(lines[i]);
    }
    return kept.join('\n');
  }
}

/// Thrown by the pipeline when [VerifierMode.fatal] is active and
/// [DraftVerifier.verify] produces at least one violation. Carries the
/// full violation list so callers can log a useful error summary.
class DraftVerificationFailedException implements Exception {
  /// Creates a [DraftVerificationFailedException].
  const DraftVerificationFailedException(this.violations);

  /// The violations that triggered the failure.
  final List<Violation> violations;

  @override
  String toString() {
    final lines = <String>['Draft verification failed:'];
    for (final v in violations) {
      lines.add(
        '  - line ${v.lineNumber} [${v.kind.name}]: '
        '${v.claim} — ${v.reason}',
      );
    }
    return lines.join('\n');
  }
}
