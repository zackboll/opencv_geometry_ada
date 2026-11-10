// Runs only in source-free metadata jobs via the GitHub API, never PR imports.
// API records, not uploaded artifacts/manifests, are the approval authority.
module.exports = async ({github, context, core}) => {
  const {owner, repo} = context.repo;
  const environment = 'documentation-policy-maintenance';
  const path = '.github/workflows/documentation.yml';
  const checkName = 'Documentation policy acceptance';
  const anchor = '23701d526bd0870de5fb126c2ecdd0b9c24913e2';
  const require = (ok, message) => { if (!ok) throw new Error(message); };
  const get = async route => (await github.request(`GET /repos/${owner}/${repo}/${route}`)).data;
  const protectedPath = n => /^(scripts\/|\.github\/|tests\/ci\/|docs\/assets\/|docs\/evidence\/)/.test(n) ||
    ['docs/requirements.txt', 'alire.toml', 'tests/alire.toml', 'docs_api.gpr', 'docs_internal.gpr',
     'docs/gnatdoc-enhancer.toml', 'docs/gnatdoc-authored.json', 'docs/shared-gnatdoc-shadow.toml',
     'docs/gnatdoc-warning-baseline.txt', 'docs/gnatdoc-coverage-baseline.txt'].includes(n);
  async function approval(runId, sha, requireCheck) {
    const run = await get(`actions/runs/${runId}`);
    require(run.event === 'pull_request' && run.path === path && run.head_sha === sha,
      'approval workflow/head identity differs');
    require(run.repository.full_name === `${owner}/${repo}`, 'approval repository differs');
    if (requireCheck) {
      require(run.conclusion === 'success', 'technical/acceptance workflow did not succeed');
      const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun,
        {owner, repo, run_id: runId, filter: 'latest', per_page: 100});
      for (const name of [checkName, 'Policy technical qualification', 'Maintainer policy approval']) {
        require(jobs.filter(j => (j.name === name || j.name.endsWith(' / ' + name)) &&
          j.conclusion === 'success').length === 1,
          `missing successful ${name}`);
      }
    }
    const reviews = await get(`actions/runs/${runId}/approvals`);
    const relevant = reviews.filter(r => r.environments.some(e => e.id === config.id));
    require(relevant.length > 0 && relevant[relevant.length - 1].state === 'approved',
      'missing approval or approval rejected');
    const reviewer = relevant[relevant.length - 1].user;
    const permission = await get(`collaborators/${encodeURIComponent(reviewer.login)}/permission`);
    require(['admin', 'maintain'].includes(permission.permission), 'approver is not a maintainer');
    require(reviewer.type === 'User', 'automatic approval is forbidden');
    return {run: runId, head: sha, reviewer: reviewer.login, environment_id: config.id};
  }
  let config;
  async function environmentConfig() {
    config = await get(`environments/${environment}`);
    const rule = config.protection_rules.find(r => r.type === 'required_reviewers');
    require(rule && rule.reviewers.length > 0, 'configure mandatory maintainer reviewers externally');
    require(config.can_admins_bypass === false, 'environment administrator bypass must be disabled');
    // Explicit maintainer authorization is required even where self-review is
    // administratively permitted (e.g. a single-maintainer repository).
    for (const entry of rule.reviewers) {
      require(entry.type === 'User', 'configure explicit maintainer users');
      const permission = await get(`collaborators/${encodeURIComponent(entry.reviewer.login)}/permission`);
      require(['admin', 'maintain'].includes(permission.permission), 'environment reviewer lacks maintainer role');
    }
  }
  if (context.eventName === 'pull_request') {
    const pr = context.payload.pull_request;
    const current = await get(`pulls/${pr.number}`);
    require(current.head.sha === pr.head.sha && current.base.sha === pr.base.sha,
      'stale PR head/base; rerun qualification');
    if (process.env.POLICY_MODE === 'maintenance') {
      await environmentConfig();
      if (process.env.VERIFY_APPROVAL === 'true') {
        core.info(JSON.stringify(await approval(context.runId, pr.head.sha, false)));
      }
    }
    return;
  }
  require(context.ref === 'refs/heads/main' && ['push', 'workflow_dispatch'].includes(context.eventName),
    'publication provenance is main-only');
  const main = await get('git/ref/heads/main');
  require(main.object.sha === context.sha, 'superseded main cannot publish');
  // Audit first-parent transitions back to the explicitly authorized contract
  // anchor. Never use push.before as a shortcut across an unauthorized merge.
  let sha = context.sha;
  const evidence = [];
  for (let count = 0; sha !== anchor; count++) {
    require(count < 500, 'provenance horizon exceeded; maintainer audit required');
    const commit = await get(`commits/${sha}`);
    require(commit.parents.length > 0, 'approved policy anchor not found');
    const parent = commit.parents[0].sha;
    const comparison = await get(`compare/${parent}...${sha}`);
    require(comparison.files && comparison.files.length < 300, 'truncated changed-file inventory');
    const changed = comparison.files.some(f => protectedPath(f.filename) ||
      (f.previous_filename && protectedPath(f.previous_filename)));
    if (changed) {
      await environmentConfig();
      require(commit.parents.length === 2, 'protected policy requires a reviewed two-parent PR merge');
      const head = commit.parents[1].sha;
      const prs = await get(`commits/${sha}/pulls`);
      const pr = prs.find(p => p.merged_at && p.merge_commit_sha === sha &&
        p.head.sha === head && p.base.ref === 'main');
      require(pr, 'protected merge has no exact-head merged PR');
      const delta = await get(`compare/${head}...${sha}`);
      require(delta.files && delta.files.length < 300 && !delta.files.some(f =>
        protectedPath(f.filename) || (f.previous_filename && protectedPath(f.previous_filename))),
        'merge substituted protected bytes absent from approved PR');
      const runs = await github.paginate(github.rest.actions.listWorkflowRuns,
        {owner, repo, workflow_id: path, head_sha: head, event: 'pull_request', per_page: 100});
      const run = runs.find(r => r.conclusion === 'success' && r.pull_requests.some(p => p.number === pr.number));
      require(run, 'no successful SHA-bound policy acceptance run');
      require(new Date(run.updated_at) <= new Date(pr.merged_at), 'approval postdates merge');
      evidence.push({merge: sha, pr: pr.number, ...await approval(run.id, head, true)});
    }
    sha = parent;
  }
  core.info(JSON.stringify({anchor, main: context.sha, transitions: evidence}));
};