"""_gen_format.py — shared rubocop format-on-emit pass for the code generators.

Every generator (generate_rest.py, generate_swml_verbs.py, generate_relay_protocol.py,
generate_swaig_payloads.py, generate_rest_tests.py) builds a ``{relative_path: source}``
dict of Ruby files. Running that raw emit through the repo's rubocop SAFE-autocorrect
(``rubocop -a``, the exact pass ``scripts/run-format.sh`` applies) BEFORE it is written or
GEN-FRESH-compared makes the committed generated tree simultaneously:

  * GEN-FRESH clean — a fresh regen reproduces byte-for-byte what is on disk, because the
    format pass is part of the emit (not a later step that would diverge the two), and
  * FMT/LINT clean — the tree is already rubocop-formatted, so it needs no whole-dir
    ``Exclude:`` in ``.rubocop.yml`` (which the GEN-IDIOM gate forbids). This mirrors the
    TypeScript port's prettier ``formatTs`` pass and the Rust port's ``rustfmt`` pass.

Cops that rubocop CANNOT safe-autocorrect (a wire-key param/class name the generator must
preserve verbatim, an irreducibly large spec-derived method/class, a spec-derived long
line) are handled at the template with a NARROW, reasoned inline ``# rubocop:disable`` —
never a blanket file suppression and never a config exclusion.

Fails LOUD if rubocop is unavailable or errors (so a broken tool can't silently ship
unformatted generated code).
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


# Cops that a spec-derived generated file legitimately cannot satisfy without diverging
# from the wire contract, and which rubocop CANNOT safe-autocorrect:
#   * Layout/LineLength                — a create/update signature or a FIELDS/attr line
#                                        is as wide as the spec's field set; wrapping it
#                                        would not shorten the irreducible surface.
#   * Metrics/{AbcSize,MethodLength,CyclomaticComplexity,PerceivedComplexity,ClassLength}
#                                      — a per-spec CRUD method / data class is as large
#                                        as the schema it mirrors (SIZE, not complexity of
#                                        logic).
#   * Naming/{MethodName,VariableName,MethodParameterName,ClassAndModuleCamelCase}
#                                      — a wire KEY (``SWML``/``SWAIG``), a reserved-word
#                                        escape (``sWAIG``), or a folded schema constant
#                                        (``Types_StatusCodes_StatusCode400``, the identical
#                                        token the cross-port surface diff compares) is
#                                        preserved verbatim; snake/camel-casing it would
#                                        change the wire/surface token.
# We wrap each generated file's body in a disable/enable PAIR for the FULL candidate set;
# the ``rubocop -a`` format pass then PRUNES each file's pair down to exactly the cops it
# actually needs (Lint/RedundantCopDisableDirective), symmetrically on both lines. This is
# a narrow, reasoned per-construct suppression — NOT a blanket file suppression and NOT a
# ``.rubocop.yml`` whole-dir exclusion — so generated code stays linted for every OTHER
# cop (real bugs, security, dead code) exactly like hand-written code.
_SPEC_DERIVED_COPS = (
    "Layout/LineLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, "
    "Metrics/PerceivedComplexity, Metrics/ClassLength, Naming/MethodName, Naming/VariableName, "
    "Naming/MethodParameterName, Naming/ClassAndModuleCamelCase"
)


def wrap_spec_derived_disables(src: str) -> str:
    """Wrap a generated file's body in a disable/enable pair for the spec-derived cops.

    Inserted right after the ``# frozen_string_literal: true`` magic comment (and its
    trailing blank line) and closed at end of file. The format pass prunes it per file.
    """
    lines = src.split("\n")
    # Find the magic comment; insert the disable after it (+ the blank line that follows).
    insert_at = 0
    for i, ln in enumerate(lines[:3]):
        if ln.startswith("# frozen_string_literal:"):
            insert_at = i + 1
            break
    # Skip a single following blank line so the disable sits above the doc banner.
    if insert_at < len(lines) and lines[insert_at].strip() == "":
        insert_at += 1
    disable = [
        "# Spec-derived generated surface: wire keys, folded schema constants, and per-schema",
        "# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the",
        "# generator's rubocop pass to exactly those that fire.",
        f"# rubocop:disable {_SPEC_DERIVED_COPS}",
    ]
    head = lines[:insert_at]
    body = lines[insert_at:]
    # Drop a trailing empty string from the split so the enable lands after real content.
    trailing_blank = body and body[-1] == ""
    if trailing_blank:
        body = body[:-1]
    enable = [f"# rubocop:enable {_SPEC_DERIVED_COPS}"]
    return "\n".join(head + disable + [""] + body + enable) + "\n"


def rubocop_format(files: dict[str, str]) -> dict[str, str]:
    """Return ``files`` with every value run through ``rubocop -a`` (safe autocorrect).

    ``files`` maps a repo-relative path (e.g. ``lib/.../foo.rb``) to its raw emitted
    source. The paths are only used so rubocop resolves the repo config and applies any
    path-specific cop context; the returned dict has the identical keys with formatted
    values. A single batched rubocop invocation formats the whole set (fast); per-file
    stdin would spawn one rubocop per file.
    """
    if not files:
        return {}
    repo = _repo_root()
    config = repo / ".rubocop.yml"
    # A UNIQUE work dir per invocation: the 5 generators run concurrently under run-ci's
    # GEN-FRESH wave, so a shared path would have them clobber each other's mirror. Kept
    # under the gitignored repo-local .sw-tmp (never a machine-wide /tmp).
    base = repo / ".sw-tmp"
    base.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=f"genfmt-{os.getpid()}-", dir=str(base)))
    try:
        for rel, src in files.items():
            p = work / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(src)
        # One batched safe-autocorrect over the mirror. ``-a`` = safe only (exactly what
        # run-format.sh applies); ``--config`` pins the repo cop set + plugins. rubocop
        # exits non-zero when residual (non-autocorrectable) offenses remain — that is
        # EXPECTED here (wire-key names etc. carry inline disables), so a non-zero exit is
        # not itself a failure; a missing/broken rubocop is (caught below via the binary
        # probe + the read-back).
        cmd = [
            "bundle",
            "exec",
            "rubocop",
            "-a",
            "--force-exclusion",
            "--no-color",
            "--config",
            str(config),
            str(work),
        ]
        # S603: fixed list-form arg vector under the default shell=False, so there
        # is no shell to interpolate into; the only non-literal elements are paths
        # this function itself built (the tempdir mirror and the repo config).
        proc = subprocess.run(cmd, cwd=str(repo), capture_output=True, text=True)  # noqa: S603
        # rubocop returns 0 (clean) or 1 (offenses remain). Any other code, or a
        # "command not found"/load error, means the tool itself failed — fail loud.
        if proc.returncode not in (0, 1):
            sys.stderr.write(proc.stdout)
            sys.stderr.write(proc.stderr)
            raise SystemExit(
                f"_gen_format: rubocop exited {proc.returncode} — cannot format generated "
                f"code (is the rubocop gem installed? try `bundle install`)"
            )
        out: dict[str, str] = {}
        for rel in files:
            out[rel] = _fix_enable_directive((work / rel).read_text())
        return out
    finally:
        if work.exists():
            shutil.rmtree(work)


def _fix_enable_directive(src: str) -> str:
    """Rewrite the trailing ``# rubocop:enable`` line to match the pruned ``# rubocop:disable``.

    rubocop's ``-a`` prunes redundant cops from BOTH the disable and enable lines, but when
    it removes the FIRST cop of a multi-cop ENABLE line it leaves a malformed leading comma
    (``# rubocop:enable, Naming/MethodName``) — a rubocop autocorrect defect. The disable
    line always prunes cleanly. So we read the surviving disable-line cop set and rewrite the
    enable line to match exactly, keeping the pair symmetric and syntactically valid. If a
    file's disable pair was pruned to nothing (no spec-derived cop fired), drop the pair.
    """
    dis_prefix = "# rubocop:disable "
    # The enable line may be well-formed ("# rubocop:enable X") or malformed by the
    # first-item-prune defect ("# rubocop:enable, X") — match the bare mode token.
    en_marker = "# rubocop:enable"
    lines = src.split("\n")
    dis_cops = ""
    for ln in lines:
        if ln.startswith(dis_prefix):
            dis_cops = ln[len(dis_prefix) :].strip()
            break
    kept: list[str] = []
    for ln in lines:
        if ln.startswith(en_marker):
            if dis_cops:
                kept.append(en_marker + " " + dis_cops)
            # else: disable was fully pruned; drop the orphan enable too.
            continue
        kept.append(ln)
    return "\n".join(kept)
