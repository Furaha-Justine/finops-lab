# FinCorp — Secure CI/CD Pipeline

Workflow file: [`.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml)
Triggers: push to `main`, pull requests into `main`, and manual
`workflow_dispatch`.

## Pipeline stages

1. **Checkout** the repo.
2. **Authenticate to AWS via GitHub OIDC** — `aws-actions/configure-aws-credentials`
   assumes `github-actions-fincorp-role` using a short-lived web identity
   token. No AWS access keys are stored in GitHub at all.
3. **Authenticate npm to CodeArtifact** — `aws codeartifact login` points npm
   at the `fincorp-internal` repository (which proxies the public npm
   registry through `npm-store`), so `npm ci` never talks to npmjs.org
   directly.
4. **Install dependencies** (`npm ci`) and **run tests** (`npm test`).
5. **Build the Docker image**, tagged with the commit SHA
   (`fincorp-app:<github.sha>`).
6. **Vulnerability gate (Trivy)** — scans the built image for HIGH/CRITICAL
   vulnerabilities *before* anything is pushed anywhere.
   - `exit-code: 1` — **the build fails if any HIGH/CRITICAL vulnerability
     with an available fix is found.** This is the literal "must fail" build
     constraint.
   - `ignore-unfixed: true` — vulnerabilities with no vendor patch available
     yet (e.g. unpatched Debian CVEs) are excluded from the gate, since no
     rebuild can remediate them. They are not hidden — see step 8.
7. **Push to ECR** — only reached if step 6 passed. The ECR repository has
   `image_tag_mutability = IMMUTABLE` (set in Terraform), so a given tag
   (the commit SHA) can only ever be pushed once; it can never be silently
   overwritten.
8. **Record ECR's native scan findings as an audit artifact** — ECR itself
   has `scan_on_push` enabled independently of the Trivy gate. This step
   waits for that scan and uploads its full findings (including anything
   `ignore-unfixed` excluded from the gate) as a downloadable GitHub Actions
   artifact, so there's a complete, unfiltered compliance record even though
   the gate itself is intentionally more lenient about unfixable CVEs.

## Supply-chain hardening decisions

- **Every third-party GitHub Action is pinned by commit SHA**, not a
  mutable version tag (e.g. `actions/checkout@9c091bb2...` with the tag as a
  comment, not `actions/checkout@v4`). This was not just theoretical
  caution: during setup, `aquasecurity/trivy-action@v0.28.0`'s internal
  dependency on `aquasecurity/setup-trivy@v0.2.1` broke because that tag had
  been deleted upstream. Pinning by SHA means a tag being deleted, moved, or
  compromised upstream cannot silently change what code runs in this
  pipeline.
- **Keyless AWS auth (OIDC)** — no long-lived IAM user credentials exist for
  CI at all, removing an entire class of leaked-secret risk.
- **Least-privilege IAM** — the CI role can push to exactly one ECR repo,
  read from exactly one CodeArtifact repo, and describe (not modify) RDS.
  It cannot touch AWS Backup, IAM, or any other resource.
- **Immutable image tags** — combined with tagging by commit SHA, this
  guarantees a given tag always refers to the exact same image bytes that
  passed the scan gate; nothing can be swapped in after the fact.

## Remediation performed on the base image

The first real pipeline run correctly **failed** the vulnerability gate: 27
HIGH/CRITICAL findings in the `node:20-slim` base image. Investigation
showed:

- 21 were Debian OS packages with **no fixed version available yet**
  (status `affected` / `fix_deferred` / `will_not_fix` in Trivy's report) —
  not remediable by rebuilding.
- 12 were in a **bundled copy of the `npm` CLI's own dependencies**
  (`/usr/local/lib/node_modules/npm/node_modules/{tar,minimatch,glob,
  cross-spawn,sigstore}`) that ships inside the base image but is never used
  at runtime (the app only needs `node`, not `npm`, once built).

Fix applied in [`fincorp-app/Dockerfile`](../fincorp-app/Dockerfile):
`apt-get upgrade` picks up available OS patches, and the unused global
`npm`/`npx` install is deleted from the runtime stage. Combined with
`ignore-unfixed: true` on the gate (see above), this produced a clean scan
and a passing pipeline run — see the [walkthrough](WALKTHROUGH.md) for the
before/after run logs.

## Verifying the constraint holds

To prove the gate genuinely blocks vulnerable images (not just that it
passed once): the first pipeline run on this repo failed at the Trivy step
with exit code 1 over the 27 findings above, before any image reached ECR.
Run history: `gh run list --repo Furaha-Justine/finops-lab`.
