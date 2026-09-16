#!/usr/bin/env python3
"""Digital Worker R1 Runtime Binding utilities for Claude Code.

R1 proves exact source-set materialization and identity handling only. It does not
claim native Claude runtime execution, Digital Worker Verification PASS, Review
approval, Product Readiness, or R2 real-provider substitution.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
BINDING_PATH = ROOT / "manifests" / "integrations" / "digital-worker-runtime-binding.json"
BOOTSTRAP_PATH = ROOT / "manifests" / "session_bootstrap.json"
RECEIPT_SCHEMA_PATH = ROOT / "schemas" / "runtime-execution-receipt.v2.schema.json"

FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
FORBIDDEN_CLAIMS = {"verification_pass", "verification_status", "domain_verification_status", "release_ready", "domain_gate_pass"}


class RuntimeBindingError(RuntimeError):
    pass


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeBindingError(f"cannot read {label}: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RuntimeBindingError(f"{label} must be a JSON object")
    return value


def require(ok: bool, message: str) -> None:
    if not ok:
        raise RuntimeBindingError(message)


def run(*args: str, cwd: Path | None = None) -> str:
    try:
        return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT).strip()
    except subprocess.CalledProcessError as exc:
        raise RuntimeBindingError(f"command failed: {' '.join(args)}\n{exc.output}") from exc


def git(root: Path, *args: str) -> str:
    return run("git", "-C", str(root), *args)


def full_sha(value: Any, label: str) -> str:
    require(isinstance(value, str) and FULL_SHA.fullmatch(value) is not None, f"{label} must be exact 40-hex")
    return value


def sha256_text(value: Any, label: str) -> str:
    require(isinstance(value, str) and SHA256.fullmatch(value) is not None, f"{label} must be lowercase SHA-256")
    return value


def nonempty(value: Any, label: str) -> str:
    require(isinstance(value, str) and bool(value.strip()), f"{label} must be non-empty")
    return value.strip()


def find_forbidden_contract_key(value: Any) -> str | None:
    """Return an exact forbidden contract field name, ignoring values and longer guardrail keys."""
    if isinstance(value, dict):
        for key, item in value.items():
            normalized = str(key).lower().replace("-", "_")
            if normalized == "asset_bundle_hash" or normalized in FORBIDDEN_CLAIMS:
                return normalized
            nested = find_forbidden_contract_key(item)
            if nested is not None:
                return nested
    elif isinstance(value, list):
        for item in value:
            nested = find_forbidden_contract_key(item)
            if nested is not None:
                return nested
    return None


def validate_local_contracts() -> dict[str, Any]:
    binding = load_json(BINDING_PATH, "runtime binding")
    bootstrap = load_json(BOOTSTRAP_PATH, "session bootstrap")
    schema = load_json(RECEIPT_SCHEMA_PATH, "runtime execution receipt schema")
    Draft202012Validator.check_schema(schema)

    require(binding.get("schema") == "claude-digital-worker-runtime-binding/v1", "runtime binding schema drift")
    require(binding.get("contract_version") == "1.0", "runtime binding version drift")
    require(binding.get("status") == "SOURCE_SET_READY_R1", "runtime binding must remain R1 source-set ready")
    require(binding.get("runtime_target") == "claude-code", "runtime target drift")
    require(binding.get("maturity_level") == "R1-binding-conformance", "R1 maturity boundary drift")
    require(binding.get("terminal_replaceability_qualified") is False, "R1 must never qualify terminal replaceability")
    require(binding.get("agent_dev_kit", {}).get("asset_profile") == "embedded-fullstack", "ADK asset profile drift")
    require(binding.get("hard_rules", {}).get("r1_is_not_r2") is True, "R1/R2 boundary missing")
    require(binding.get("hard_rules", {}).get("runtime_output_is_not_verification_pass") is True, "runtime/domain authority boundary missing")

    require(bootstrap.get("schema") == "claude-session-bootstrap/v1", "bootstrap schema drift")
    require(bootstrap.get("role") == "thin-session-bootstrap", "bootstrap role drift")
    require(set(bootstrap.get("modes", {})) == {"L0", "L1", "L2"}, "bootstrap modes drift")
    require(bootstrap.get("governance_escalation", {}).get("l1_to_l2_requires_new_bootstrap") is True, "L1->L2 bootstrap ratchet missing")

    for label, document in (("runtime binding", binding), ("runtime execution receipt schema", schema)):
        forbidden = find_forbidden_contract_key(document)
        require(forbidden is None, f"forbidden authority/bundle field entered {label}: {forbidden}")
    return binding


def validate_adk_contract_root(binding: dict[str, Any], root: Path) -> None:
    adk = binding["agent_dev_kit"]
    expected_commit = adk["consumer_contract_commit"]
    require(git(root, "rev-parse", "HEAD") == expected_commit, "ADK consumer-contract checkout commit drift")
    contract = root / adk["consumer_contract_ref"]
    require(contract.is_file(), "ADK Claude consumer contract missing")
    require(digest(load_json(contract, "ADK Claude consumer contract")) == adk["consumer_contract_canonical_sha256"], "ADK Claude consumer contract canonical digest mismatch")


def validate_adk_release_root(binding: dict[str, Any], root: Path) -> None:
    adk = binding["agent_dev_kit"]
    release = adk["release"]
    commit = release["commit"]
    require(git(root, "rev-parse", "HEAD") == commit, "ADK release checkout commit drift")
    require(git(root, "rev-parse", f"{commit}^{{tree}}") == release["tree"], "ADK release tree drift")
    require(git(root, "rev-parse", f"{commit}:manifest.json") == release["manifest_blob"], "ADK release manifest blob drift")
    require(git(root, "rev-parse", f"{release['tag']}^{{}}") == commit, "ADK release tag does not peel to immutable commit")
    target = root / adk["target_contract_ref"]
    require(target.is_file(), "ADK Claude target contract missing")
    require(digest(load_json(target, "ADK Claude target contract")) == adk["target_contract_canonical_sha256"], "ADK Claude target contract digest mismatch")


def materialize(args: argparse.Namespace) -> dict[str, Any]:
    binding = validate_local_contracts()
    contract_root = args.adk_contract_root.resolve()
    release_root = args.adk_release_root.resolve()
    out = args.out.resolve()
    runtime_profile = args.runtime_profile
    require(runtime_profile in binding["runtime_profiles"], "runtime profile is not declared")
    validate_adk_contract_root(binding, contract_root)
    validate_adk_release_root(binding, release_root)

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="claude-adk-export-") as tmp:
        export_parent = Path(tmp) / "export"
        command = [
            str(release_root / "scripts" / "devkit.sh"),
            "export",
            "--target", "claude-code",
            "--profile", binding["agent_dev_kit"]["asset_profile"],
            "--out", str(export_parent),
            "--clean",
            "--summary-json",
        ]
        export_summary_raw = run(*command, cwd=release_root)
        try:
            export_summary = json.loads(export_summary_raw.splitlines()[-1])
        except json.JSONDecodeError as exc:
            raise RuntimeBindingError(f"ADK export did not return JSON summary: {export_summary_raw}") from exc
        require(export_summary.get("status") == "pass", "ADK export did not pass")
        target_root = export_parent / "claude-code"
        inventory_path = target_root / "adk-export-manifest.json"
        inventory = load_json(inventory_path, "ADK export inventory")
        require(inventory.get("schema") == "adk-export-manifest/v2", "ADK export inventory schema drift")
        require(inventory.get("target") == "claude-code", "ADK export target drift")
        require("embedded-fullstack" in inventory.get("profiles", []), "ADK export lost embedded-fullstack profile")

        enriched_files: list[dict[str, Any]] = []
        release_commit = binding["agent_dev_kit"]["release"]["commit"]
        for item in inventory.get("files", []):
            require(isinstance(item, dict), "ADK export inventory file entry must be object")
            source = nonempty(item.get("source"), "ADK export source")
            source_blob = git(release_root, "rev-parse", f"{release_commit}:{source}")
            full_sha(source_blob, f"source blob for {source}")
            enriched_files.append({
                "kind": item.get("kind"),
                "name": item.get("name"),
                "source": source,
                "source_blob": source_blob,
                "path": item.get("path"),
                "sha256": item.get("sha256"),
                "mode": item.get("mode"),
            })

        source_set_payload = {
            "schema": "claude-adk-source-set/v1",
            "runtime_target": "claude-code",
            "provider_contract_commit": binding["agent_dev_kit"]["consumer_contract_commit"],
            "provider_contract_canonical_sha256": binding["agent_dev_kit"]["consumer_contract_canonical_sha256"],
            "release_identity": binding["agent_dev_kit"]["release"],
            "asset_profile": binding["agent_dev_kit"]["asset_profile"],
            "target_contract_canonical_sha256": binding["agent_dev_kit"]["target_contract_canonical_sha256"],
            "export_manifest_sha256": file_sha256(inventory_path),
            "files": enriched_files,
        }
        source_set = dict(source_set_payload)
        source_set["identity"] = "sha256:" + digest(source_set_payload)

        distribution_root = out / "distribution"
        shutil.copytree(target_root, distribution_root)
        distribution_files = []
        for path in sorted(p for p in distribution_root.rglob("*") if p.is_file()):
            distribution_files.append({
                "path": path.relative_to(distribution_root).as_posix(),
                "sha256": file_sha256(path),
            })
        runtime_commit = git(ROOT, "rev-parse", "HEAD")
        full_sha(runtime_commit, "Claude runtime binding commit")
        distribution_payload = {
            "schema": "claude-runtime-distribution/v1",
            "runtime_binding_repository": "jiying2007/claude",
            "runtime_binding_commit": runtime_commit,
            "runtime_target": "claude-code",
            "runtime_profile": runtime_profile,
            "runtime_source_set_identity_ref": source_set["identity"],
            "files": distribution_files,
        }
        distribution = dict(distribution_payload)
        distribution["identity"] = "sha256:" + digest(distribution_payload)

        (out / "source-set.json").write_text(json.dumps(source_set, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        (out / "runtime-distribution.json").write_text(json.dumps(distribution, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    result = {
        "schema": "claude-runtime-materialization-result/v1",
        "status": "pass",
        "maturity": "R1-binding-conformance",
        "r2_qualified": False,
        "runtime_source_set_identity_ref": source_set["identity"],
        "runtime_distribution_identity_ref": distribution["identity"],
        "agents": export_summary.get("agents"),
        "skills": export_summary.get("skills"),
        "output": str(out),
    }
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return result


def validate_l2_identity(request: dict[str, Any]) -> None:
    full_sha(request.get("exact_base_commit"), "exact_base_commit")
    for field in ("work_item_id", "run_id", "engineering_package_id"):
        nonempty(request.get(field), field)
    governance = request.get("digital_worker_governance_identity")
    require(isinstance(governance, dict), "digital_worker_governance_identity is required")
    full_sha(governance.get("provider_commit"), "digital_worker provider_commit")
    sha256_text(governance.get("contract_catalog_digest"), "digital_worker contract_catalog_digest")
    require(isinstance(governance.get("selected_domain_refs"), list) and governance["selected_domain_refs"], "selected_domain_refs required")
    require(isinstance(governance.get("selected_routing_refs"), list) and governance["selected_routing_refs"], "selected_routing_refs required")
    knowledge = request.get("knowledge_context_identity")
    require(isinstance(knowledge, dict), "knowledge_context_identity is required")
    full_sha(knowledge.get("provider_commit"), "knowledge provider_commit")
    sha256_text(knowledge.get("provider_contract_digest"), "knowledge provider_contract_digest")
    nonempty(knowledge.get("context_fingerprint"), "knowledge context_fingerprint")


def bootstrap(args: argparse.Namespace) -> dict[str, Any]:
    binding = validate_local_contracts()
    request = load_json(args.request.resolve(), "bootstrap request")
    mode = request.get("mode")
    require(mode in {"L0", "L1", "L2"}, "bootstrap mode must be L0/L1/L2")
    source_set = load_json(args.materialization_root.resolve() / "source-set.json", "source-set")
    distribution = load_json(args.materialization_root.resolve() / "runtime-distribution.json", "runtime distribution")
    require(request.get("runtime_source_set_identity_ref") == source_set.get("identity"), "bootstrap source-set identity mismatch")
    require(request.get("runtime_distribution_identity_ref") == distribution.get("identity"), "bootstrap distribution identity mismatch")
    if mode == "L2":
        validate_l2_identity(request)
        if request.get("escalated_from") == "L1":
            nonempty(request.get("prior_session_bootstrap_ref"), "prior_session_bootstrap_ref")
            require(request.get("prior_context_disposition") == "provisional-only", "L1 context must remain provisional during L2 escalation")

    execution_source_set_payload = {
        "schema": "claude-execution-source-set/v1",
        "mode": mode,
        "runtime_source_set_identity_ref": source_set["identity"],
        "runtime_distribution_identity_ref": distribution["identity"],
        "work_identity": {
            "work_item_id": request.get("work_item_id"),
            "run_id": request.get("run_id"),
            "engineering_package_id": request.get("engineering_package_id"),
            "exact_base_commit": request.get("exact_base_commit"),
        },
        "digital_worker_governance_identity": request.get("digital_worker_governance_identity"),
        "knowledge_context_identity": request.get("knowledge_context_identity"),
    }
    execution_source_set = dict(execution_source_set_payload)
    execution_source_set["identity"] = "sha256:" + digest(execution_source_set_payload)
    session_payload = {
        "schema": "claude-session-bootstrap/v1",
        "status": "ready",
        "mode": mode,
        "runtime_binding_repository": "jiying2007/claude",
        "runtime_binding_commit": git(ROOT, "rev-parse", "HEAD"),
        "runtime_target": "claude-code",
        "runtime_profile": distribution["runtime_profile"],
        "agent_dev_kit_release": binding["agent_dev_kit"]["release"],
        "execution_source_set": execution_source_set,
        "formal_evidence": mode == "L2",
    }
    session = dict(session_payload)
    session["identity"] = "sha256:" + digest(session_payload)
    text = json.dumps(session, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.resolve().write_text(text, encoding="utf-8")
    print(text, end="")
    return session


def contains_forbidden_claim(value: Any) -> bool:
    if isinstance(value, dict):
        for key, item in value.items():
            normalized = str(key).lower().replace("-", "_")
            if normalized in FORBIDDEN_CLAIMS:
                if item is True or (isinstance(item, str) and item.lower() in {"pass", "passed", "success", "ready"}):
                    return True
            if contains_forbidden_claim(item):
                return True
    elif isinstance(value, list):
        return any(contains_forbidden_claim(item) for item in value)
    return False


def validate_receipt_document(receipt: dict[str, Any]) -> None:
    schema = load_json(RECEIPT_SCHEMA_PATH, "receipt schema")
    Draft202012Validator.check_schema(schema)
    errors = sorted(Draft202012Validator(schema).iter_errors(receipt), key=lambda e: list(e.absolute_path))
    if errors:
        raise RuntimeBindingError("receipt schema validation failed: " + "; ".join(error.message for error in errors[:3]))
    require(receipt.get("verification_pass_claimed") is False, "execution receipt must disclaim Verification PASS")
    require(not contains_forbidden_claim(receipt), "execution receipt contains forbidden domain/qualification claim")


def receipt(args: argparse.Namespace) -> dict[str, Any]:
    value = load_json(args.input.resolve(), "observed execution receipt")
    validate_receipt_document(value)
    text = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.resolve().write_text(text, encoding="utf-8")
    result = {"status": "pass", "sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(), "receipt": value}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return result


def self_test(args: argparse.Namespace) -> None:
    binding = validate_local_contracts()
    require(binding["terminal_replaceability_qualified"] is False, "R1 self-test must not qualify R2")
    bad = {
        "schema_version": 2,
        "status": "completed",
        "runtime": "claude-code",
        "frozen_inputs_sha256": "a" * 64,
        "verification_pass_claimed": False,
        "runtime_identity": {
            "runtime_binding_repository": "jiying2007/claude",
            "runtime_binding_commit": "b" * 40,
            "runtime_target": "claude-code",
            "runtime_profile": "solo-dev",
            "runtime_host": "ci",
            "runtime_provider": "anthropic",
            "runtime_version": "test-only",
            "runtime_source_set_identity_ref": "sha256:" + "c" * 64,
            "runtime_distribution_identity_ref": "sha256:" + "d" * 64,
        },
        "execution": {
            "started_at": "2026-09-16T00:00:00Z",
            "completed_at": "2026-09-16T00:00:01Z",
            "result_identity_ref": "fixture-only",
            "source_identity_ref": None,
            "exit_code": 0,
            "summary": "contract fixture only",
        },
        "evidence_refs": ["fixture://contract-only"],
    }
    validate_receipt_document(bad)
    injected = json.loads(json.dumps(bad))
    injected["execution"]["verification_status"] = "PASS"
    require(contains_forbidden_claim(injected), "forbidden verification claim detector regressed")
    if args.materialization_root:
        source_set = load_json(args.materialization_root.resolve() / "source-set.json", "source-set")
        distribution = load_json(args.materialization_root.resolve() / "runtime-distribution.json", "distribution")
        require(source_set.get("schema") == "claude-adk-source-set/v1", "materialized source-set schema drift")
        require(distribution.get("schema") == "claude-runtime-distribution/v1", "materialized distribution schema drift")
        require(distribution.get("runtime_source_set_identity_ref") == source_set.get("identity"), "distribution/source-set identity mismatch")
    print("Digital Worker Claude R1 binding self-test PASS")


def parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser(description=__doc__)
    sub = top.add_subparsers(dest="command", required=True)
    sub.add_parser("validate")
    mat = sub.add_parser("materialize")
    mat.add_argument("--adk-contract-root", type=Path, required=True)
    mat.add_argument("--adk-release-root", type=Path, required=True)
    mat.add_argument("--out", type=Path, required=True)
    mat.add_argument("--runtime-profile", default="solo-dev")
    boot = sub.add_parser("bootstrap")
    boot.add_argument("--request", type=Path, required=True)
    boot.add_argument("--materialization-root", type=Path, required=True)
    boot.add_argument("--output", type=Path)
    rec = sub.add_parser("receipt")
    rec.add_argument("--input", type=Path, required=True)
    rec.add_argument("--output", type=Path)
    st = sub.add_parser("self-test")
    st.add_argument("--materialization-root", type=Path)
    return top


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "validate":
            validate_local_contracts()
            print("Digital Worker Claude R1 contract validation PASS")
        elif args.command == "materialize":
            materialize(args)
        elif args.command == "bootstrap":
            bootstrap(args)
        elif args.command == "receipt":
            receipt(args)
        else:
            self_test(args)
    except (OSError, RuntimeBindingError, json.JSONDecodeError) as exc:
        print(f"[BLOCKED] {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
