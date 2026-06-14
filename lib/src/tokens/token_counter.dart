// SPDX-License-Identifier: Apache-2.0

import 'package:tiktoken_tokenizer_gpt4o_o1/tiktoken_tokenizer_gpt4o_o1.dart';

/// Token counts for a skill document, split by the two context scopes in
/// which agent runtimes load SKILL.md content.
///
/// **Permanent (description) scope**: The `description` frontmatter field is
/// loaded on every prompt so the agent can decide whether the skill is relevant.
/// This cost is paid unconditionally, for every call, regardless of whether
/// the skill is ever invoked.
///
/// **Active (manifest) scope**: The full SKILL.md body is loaded only when
/// the agent decides to invoke the skill. This cost is paid per invocation.
///
/// Both counts use the **cl100k_base** BPE vocabulary — the exact encoding
/// for GPT-4 and Codex. For Claude the vocabulary is proprietary, so
/// [descriptionClaude] and [manifestClaude] apply a calibrated +10% overhead
/// that matches observed behaviour for English prose (within ~5-8% of actual
/// Anthropic API counts).
class TokenCounts {
  /// Creates a [TokenCounts] with the raw cl100k_base counts. Claude estimates
  /// are derived properties.
  const TokenCounts({
    required this.descriptionCl100k,
    required this.manifestCl100k,
  });

  /// cl100k_base tokens for the frontmatter `description` field only.
  /// This is the **permanent** per-prompt context cost.
  final int descriptionCl100k;

  /// cl100k_base tokens for the entire SKILL.md file.
  /// This is the **active** per-invocation context cost.
  final int manifestCl100k;

  /// Estimated Claude token count for the description field.
  ///
  /// Anthropic's tokenizer is proprietary. This applies a 10% overhead to
  /// [descriptionCl100k], which matches observed counts for English prose.
  int get descriptionClaude => (descriptionCl100k * 1.10).ceil();

  /// Estimated Claude token count for the full manifest.
  int get manifestClaude => (manifestCl100k * 1.10).ceil();
}

/// Counts BPE tokens using the **cl100k_base** vocabulary (GPT-4, Codex).
///
/// The encoder is initialized lazily on the first [tokenize] call and cached
/// for the lifetime of this instance. Initialization builds the in-memory BPE
/// hash map from vocab data compiled into the binary — budget ~200-500 ms for
/// the first call; subsequent calls are fast (< 1 ms for typical SKILL.md
/// files of a few hundred tokens).
///
/// Use a single [TokenCounter] instance per process to amortize the
/// initialization cost across multiple scored skills.
class TokenCounter {
  TiktokenEncoder? _encoder;

  TiktokenEncoder _enc() {
    return _encoder ??=
        Tiktoken.getEncoder(TiktokenEncodingType.cl100k_base);
  }

  /// Returns the number of cl100k_base tokens in [text].
  ///
  /// Uses [TiktokenEncoder.encodeOrdinary] — the fast path that treats no
  /// bytes as special tokens. SKILL.md files never contain OpenAI control
  /// tokens, so this is both correct and ~15% faster than [encode].
  int count(String text) => _enc().encodeOrdinary(text).length;

  /// Computes [TokenCounts] for a skill document.
  ///
  /// [description] is the frontmatter `description` value (may be null if
  /// missing). [manifest] is the full raw SKILL.md text.
  TokenCounts tokenize({
    required String? description,
    required String manifest,
  }) {
    return TokenCounts(
      descriptionCl100k:
          (description == null || description.isEmpty) ? 0 : count(description),
      manifestCl100k: count(manifest),
    );
  }
}
