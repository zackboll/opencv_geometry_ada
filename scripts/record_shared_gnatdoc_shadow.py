#!/usr/bin/env python3
"""Fail-closed independent readiness recording, distinct from production readiness."""
import argparse
from pathlib import Path
import sys

from qualify_shared_gnatdoc_shadow import (
    BASE, CORE, ENHANCER, TRANSITION_SHA256, file_hashes, read, regular, require, sha,
    trusted_inputs, verify_publication, write,
)


def record(workspace):
    workspace.mkdir(parents=True, exist_ok=True)
    result = {"disposition": "PARTIAL_SHADOW_COMPATIBILITY", "full_shadow_qualification": False,
              "non_deployable": True, "production_migration_ready": False,
              "production_https_verified": False, "enhancer": ENHANCER, "failures": []}
    try:
        trusted_inputs()
        q = read(workspace / "qualification.json")
        require(not q.get("failure") and not q.get("exploratory_only"), "failed/exploratory qualification")
        require(q["consumer_start"] == BASE and q["core"] == CORE and
                q["enhancer"] == q["tool"]["revision"] == ENHANCER and
                q["authority_transition_sha256"] == TRANSITION_SHA256, "stale qualification identities")
        from qualify_shared_gnatdoc_shadow import ROOT, git
        require(q["consumer_tested"] == git(ROOT, "rev-parse", "HEAD").decode().strip(), "stale Geometry HEAD")
        require(q["deterministic"] is True and q["byte_idempotent"] is True, "missing determinism/idempotence")
        require(q["legacy_deterministic"] is True and q["legacy_byte_idempotent"] is True,
                "missing original determinism/idempotence")
        require(sha(regular(workspace / "commands.json")) == q["commands_sha256"], "command provenance changed")
        for command in read(workspace / "commands.json"):
            require(sha(regular(workspace / command["log"])) == command["sha256"], "execution log changed")
        require(file_hashes(workspace / "pristine-first") == file_hashes(workspace / "pristine-second") ==
                q["pristine_sha256"], "pristine binding differs")
        require(file_hashes(workspace / "first/_site") == file_hashes(workspace / "second/_site") ==
                q["shadow_sha256"], "output binding differs")
        verification = verify_publication(workspace)
        require(verification == q["verification"], "independent verification differs")
        require(q["documentation_tests"]["executed"] >= 232 and q["documentation_tests"]["status"] == "pass",
                "missing original documentation tests")
        from qualify_shared_gnatdoc_shadow import registered_cases, aunit_results
        require(q["historical"]["revision"] == BASE and
                q["historical"]["aunit"]["registered"] == 542,
                "missing historical AUnit baseline")
        for data, source in ((q["aunit"], workspace / "legacy"),
                             (q["historical"]["aunit"], workspace / "historical")):
            require(data["cases"] == registered_cases(source), "stale AUnit registrations")
            logs = [command for command in read(workspace / "commands.json")
                    if command["argv"] == ["alr", "-n", "run"] and
                    command["cwd"] == str(source / "tests") and command["exit"] == 0]
            require(len(logs) == 1 and aunit_results(source, regular(
                workspace / logs[0]["log"]).decode()) == data, "missing executed AUnit evidence")
        require(len(q["examples"]) == 6 and len({e["main"] for e in q["examples"]}) == 6 and
                all(e["build_exit"] == e["run_exit"] == 0 for e in q["examples"]), "missing compiled examples")
        expected_gate = {"coverage": "Documentation coverage: 452/452 items (100.0%); 0 newly undocumented, 0 newly documented",
                         "warnings": "GNATdoc warning delta: 0 added, 0 removed"}
        require(all(q[n] == expected_gate for n in ("legacy_gates", "native_gates", "shadow_gates")),
                "missing original warning/coverage ratchets")
        reports = {}
        qualification_sha = sha(regular(workspace / "qualification.json"))
        for name in ("browser", "negative", "original-browser"):
            evidence = read(workspace / (name + ".json"))
            require(evidence["status"] == "pass" and evidence["run_id"] == q["run_id"] and
                    evidence["consumer_tested"] == q["consumer_tested"] and
                    evidence["qualification_sha256"] == qualification_sha and
                    evidence["tested_shadow_sha256"] == q["shadow_sha256"], "stale/mismatched " + name)
            reports[name] = evidence
        require(reports["browser"]["matrix_cells"] == 8 and reports["browser"]["executed"] >= 4200 and
                len(reports["browser"]["history_traces"]) == 16, "incomplete Chromium matrix/history")
        require(reports["negative"]["executed"] >= 25 and reports["negative"]["restored_and_verified"] and
                reports["negative"]["restored_shadow_sha256"] == q["shadow_sha256"], "incomplete tamper restoration")
        require(set(reports["original-browser"]["suites"]) ==
                {"core_symbol_router", "presentation", "navigation", "guides"}, "original browser gates missing")
        result.update({"disposition": "HOSTED_CI_PENDING", "full_shadow_qualification": True,
                       "consumer_tested": q["consumer_tested"], "run_id": q["run_id"],
                       "qualification_sha256": qualification_sha,
                       "reports_sha256": {n: sha(regular(workspace / (n + ".json"))) for n in reports},
                       "hosted_exact_head": "must be checked against immutable Actions run, never inferred locally"})
    except (ValueError, OSError, KeyError) as exc:
        result["failures"].append(str(exc))
    write(workspace / "readiness.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=lambda p: Path(p).absolute(), required=True)
    result = record(parser.parse_args().workspace)
    print(result)
    sys.exit(0 if result["full_shadow_qualification"] else 1)