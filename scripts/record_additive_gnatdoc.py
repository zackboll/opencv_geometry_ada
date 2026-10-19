#!/usr/bin/env python3
"""Independent fail-closed successor recorder; never approves a policy revision."""
import argparse
from pathlib import Path

from additive_gnatdoc_policy import (
    ROOT, read, regular, require, sha, write, file_hashes, git,
)
from qualify_additive_gnatdoc import verify, historical_verify


def record(workspace, repository, revision, policy_revision, historical_workspace,
           fixture_workspace=None):
    workspace.mkdir(parents=True, exist_ok=True)
    result = {"disposition": "SUCCESSOR_TRUST_POLICY_NOT_ESTABLISHED",
              "local_qualification_complete": False, "policy_approved": False,
              "non_deployable": True, "failures": []}
    try:
        q = read(workspace / "qualification.json")
        require(q["status"] == "pass" and not q.get("failure"), "failed component qualification")
        require(q["candidate"] == revision and q["policy_revision"] == policy_revision,
                "substituted qualification identities")
        synthetic = q.get("synthetic_not_for_release", False)
        independently_verified = verify(workspace, repository, revision, policy_revision, synthetic)
        # JSON serializes source token tuples as lists. Compare canonical JSON.
        import json
        require(json.loads(json.dumps(independently_verified)) == q["verification"],
                "recorded verification differs from independent reconstruction")
        commands = read(workspace / "commands.json")
        require(sha(regular(workspace / "commands.json")) == q["commands_sha256"],
                "command provenance changed")
        for command in commands:
            require(command["exit"] == 0 and sha(regular(workspace / command["log"])) == command["sha256"],
                    "failed or falsified executed command")
        runs = [c for c in commands if c["argv"] == ["alr", "-n", "run"] and
                c["cwd"] == str(workspace / "source/tests")]
        require(len(runs) == 1 and regular(workspace / runs[0]["log"]).decode().strip() ==
                regular(workspace / "aunit.log").decode().strip(), "AUnit execution evidence missing")
        require(file_hashes(workspace / "first/_site") == file_hashes(workspace / "second/_site") ==
                q["shadow_sha256"], "two current outputs differ")
        # Require all six example programs to have actually executed, not a
        # count or an editable success claim in qualification.json.
        from qualify_shared_gnatdoc_shadow import EXAMPLES
        expected_examples = {str(workspace / "source/obj/docs-example/example")}
        expected_examples |= {str(workspace / "source/obj/docs-examples" / name) for name in EXAMPLES}
        require(expected_examples <= {c["argv"][0] for c in commands if len(c["argv"]) == 1},
                "compiled example execution missing")
        reports = {}
        for name in ("browser", "negative"):
            report = read(workspace / (name + ".json"))
            require(report["status"] == "pass" and report["candidate"] == revision and
                    report["run_id"] == q["run_id"] and report["qualification_sha256"] ==
                    sha(regular(workspace / "qualification.json")) and report["site_sha256"] ==
                    q["shadow_sha256"], "stale or failed " + name)
            reports[name] = report
        browser = reports["browser"]
        expected_cells = {(w, t, j) for w in (1280, 390) for t in ("light", "dark") for j in (True, False)}
        require(len(browser["cells"]) == 8 and {(c["width"], c["theme"], c["javascript"])
                for c in browser["cells"]} == expected_cells, "incomplete browser matrix")
        expected_entries = [[p, i["profile"], i["href"]] for p, _, groups in
                            independently_verified["comparison"]["navigation"]
                            for _, _, items in groups for i in items]
        require(all(c["visited"] == expected_entries for c in browser["cells"]),
                "not every derived current navigation entry exercised")
        require(len(browser["history"]) == 16 and
                all(sum(h["width"] == w and h["theme"] == t for h in browser["history"]) == 4
                    for w in (1280, 390) for t in ("light", "dark")), "history coverage missing")
        require(reports["negative"]["restored_and_verified"] and
                reports["negative"]["executed"] == len(reports["negative"]["attacks"]) and
                reports["negative"]["executed"] >= 25 and
                all(a["restored_and_verified"] and a["rejection"] for a in reports["negative"]["attacks"]),
                "incomplete successor attack/restoration evidence")
        require(historical_verify(workspace, historical_workspace) ==
                q["predecessor"]["qualification_sha256"], "historical evidence changed")
        historical_negative = read(historical_workspace / "negative.json")
        require(historical_negative["status"] == "pass" and historical_negative["executed"] >= 30 and
                historical_negative["restored_and_verified"], "historical 30-attack threshold lost")
        if not synthetic:
            require(fixture_workspace is not None, "positive additive fixture missing")
            fixture = read(fixture_workspace / "readiness.json")
            require(fixture["local_qualification_complete"] and fixture["synthetic_not_for_release"] and
                    fixture["policy_revision"] == policy_revision, "positive fixture not qualified")
            fixture_q = read(fixture_workspace / "qualification.json")
            require(fixture["qualification_sha256"] == sha(regular(fixture_workspace / "qualification.json")),
                    "fixture evidence changed")
            require(fixture_q["verification"]["rules"]["declarations"] ==
                    independently_verified["rules"]["declarations"] + 2,
                    "fixture declaration delta differs from two source operations")
            require(fixture_q["verification"]["aunit"]["registered"] ==
                    independently_verified["aunit"]["registered"] + 1,
                    "fixture registration delta differs")
        result.update({"disposition": "HOSTED_CI_PENDING", "local_qualification_complete": True,
                       "policy_revision": policy_revision, "candidate": revision,
                       "synthetic_not_for_release": synthetic,
                       "qualification_sha256": sha(regular(workspace / "qualification.json")),
                       "report_sha256": {n: sha(regular(workspace / (n + ".json"))) for n in reports},
                       "hosted_and_human_approval": "not inferred from local tests"})
    except (ValueError, OSError, KeyError, TypeError) as error:
        result["failures"].append(str(error))
    write(workspace / "readiness.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "candidate-repository", "historical-workspace"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--fixture-workspace", type=Path)
    for name in ("candidate-revision", "policy-revision"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    result = record(args.workspace, args.candidate_repository, args.candidate_revision,
                    args.policy_revision, args.historical_workspace, args.fixture_workspace)
    print(result)
    raise SystemExit(0 if result["local_qualification_complete"] else 1)