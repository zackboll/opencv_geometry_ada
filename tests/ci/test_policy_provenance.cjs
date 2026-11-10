// node --test tests/ci/test_policy_provenance.cjs
const {test} = require('node:test');
const assert = require('node:assert/strict');
const verify = require('../../.github/scripts/documentation-policy-provenance.cjs');
const anchor = '23701d526bd0870de5fb126c2ecdd0b9c24913e2';
const head = 'a'.repeat(40), merge = 'b'.repeat(40);
const path = '.github/workflows/documentation.yml';
function fixture({approved = true, technical = true, bypass = false, reviewers = true,
                  substitute = false, direct = false, actor = 'User', permission = 'admin',
                  stale = false, headMismatch = false, ordinary = false} = {}) {
  const run = {id: 42, event: 'pull_request', path, head_sha: headMismatch ? merge : head,
    repository: {full_name: 'owner/repo'}, conclusion: technical ? 'success' : 'failure',
    pull_requests: [{number: 7}], updated_at: '2026-11-10T00:00:00Z'};
  const records = {
    'git/ref/heads/main': {object: {sha: stale ? head : merge}},
    [`commits/${merge}`]: {parents: direct ? [{sha: anchor}] : [{sha: anchor}, {sha: head}]},
    [`compare/${anchor}...${merge}`]: {files: [{filename: ordinary ? 'README.md' : 'scripts/verifier.py'}]},
    [`compare/${head}...${merge}`]: {files: substitute ? [{filename: 'scripts/verifier.py'}] : []},
    [`commits/${merge}/pulls`]: [{number: 7, merged_at: '2026-11-10T01:00:00Z',
      merge_commit_sha: merge, head: {sha: head}, base: {ref: 'main'}}],
    'environments/documentation-policy-maintenance': {id: 17, can_admins_bypass: bypass,
      protection_rules: reviewers ? [{type: 'required_reviewers',
        reviewers: [{type: 'User', reviewer: {login: 'maintainer'}}]}] : []},
    'collaborators/maintainer/permission': {permission},
    'actions/runs/42': run,
    'actions/runs/42/approvals': [{state: approved ? 'approved' : 'rejected',
      environments: [{id: 17}], user: {login: 'maintainer', type: actor}}],
    'pulls/7': {head: {sha: stale ? merge : head}, base: {sha: anchor}},
  };
  const github = {request: async route => {
    const key = route.replace('GET /repos/owner/repo/', '');
    assert.ok(key in records, 'unexpected API request: ' + key);
    return {data: records[key]};
  }, rest: {actions: {listJobsForWorkflowRun: 'jobs', listWorkflowRuns: 'runs'}},
  paginate: async endpoint => endpoint === 'runs' ? [run] :
    ['Documentation policy acceptance', 'Policy technical qualification', 'Maintainer policy approval']
      .map(name => ({name, conclusion: technical ? 'success' : 'failure'}))};
  const context = {repo: {owner: 'owner', repo: 'repo'}, sha: merge,
    ref: 'refs/heads/main', eventName: 'push', runId: 42,
    payload: {pull_request: {number: 7, head: {sha: head}, base: {sha: anchor}}}};
  return {github, context, core: {info: () => {}}};
}
test('approved exact-head main merge qualifies', async () => verify(fixture()));
test('ordinary main needs no new policy approval', async () => verify(fixture({ordinary: true})));
for (const [name, options] of Object.entries({
  rejected: {approved: false}, technical: {technical: false}, bypass: {bypass: true},
  missingReviewers: {reviewers: false}, mergeSubstitution: {substitute: true},
  directPush: {direct: true}, automatic: {actor: 'Bot'}, nonMaintainer: {permission: 'write'},
  supersededMain: {stale: true}, substitutedHead: {headMismatch: true},
})) test(`${name} cannot authorize main policy`, async () => assert.rejects(verify(fixture(options))));
test('PR approval checks live exact head', async () => {
  process.env.POLICY_MODE = 'maintenance';
  process.env.VERIFY_APPROVAL = 'true';
  const f = fixture();
  f.context.eventName = 'pull_request';
  await verify(f);
  const stale = fixture({stale: true});
  stale.context.eventName = 'pull_request';
  await assert.rejects(verify(stale), /stale PR/);
  const rejected = fixture({approved: false});
  rejected.context.eventName = 'pull_request';
  await assert.rejects(verify(rejected), /rejected/);
  delete process.env.POLICY_MODE;
  delete process.env.VERIFY_APPROVAL;
});