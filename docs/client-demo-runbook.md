# Client Demo Runbook: Startup IDP on AWS ECS

For whoever at DevOps94 presents the Internal Developer Platform demo to a startup client.
Length: about 12 minutes plus questions.

## What the client sees

A developer fills in a 3-field form in Backstage. About 5 minutes later their new service
is running on AWS ECS Fargate: tested, security-scanned, with its image in ECR, its
pipeline history, its AWS status and its docs all on one page. Nobody touches the AWS
console, Terraform or YAML.

```
Developer ─► Backstage "Create" (name, description, team)
               ├─► GitHub repo: app + tests, Dockerfile, Terraform, CI/CD, catalog entry, docs
               └─► Catalog entry (owner, system, links)
            GitHub Actions (reusable golden-path pipeline, OIDC → AWS, no stored keys)
               tests ∥ Gitleaks + Trivy → build → Trivy image scan → ECR → Terraform → ECS dev
            AWS: shared VPC + ALB + ECS cluster (Fargate Spot) · per service: ECR, task def,
                 service, target group, path rule, log group, IAM roles
            Backstage component page: CI runs · Amazon ECS status · TechDocs · links
```

## Addresses

| What | URL |
|---|---|
| Backstage | https://52.66.252.27 (self-signed certificate: Advanced → Proceed) |
| Services (dev) | http://devops94-idp-alb-1896325251.ap-south-1.elb.amazonaws.com/dev/&lt;service&gt;/ |
| Reference service | …/dev/reference-api/ |
| Golden-path pipeline | https://github.com/0019-KDU/idp-platform/blob/main/.github/workflows/ecs-service.yml |
| Template source | https://github.com/0019-KDU/idp-platform/tree/main/templates/ecs-nodejs-service |

## Before every demo (15 min, the day before)

1. **Public IP unchanged?** The EC2 instance has no Elastic IP, so a stop/start changes it.
   `curl -s https://checkip.amazonaws.com` on the server. If it changed:
   `sudo deploy/scripts/enable-nginx-selfsigned.sh <ip>`, update `BACKSTAGE_BASE_URL` in
   `/etc/backstage/backstage.env`, recreate the container, and update the GitHub OAuth App
   (homepage + redirect URI).
2. **GitHub token valid?** The Backstage token expires **2026-10-23**. Renew it before then
   (scopes `repo`, `workflow`) in `/etc/backstage/backstage.env`, then recreate the container.
3. **Health:** `deploy/scripts/healthcheck.sh --insecure https://<ip>` shows all OK.
4. **Services running:** open `/dev/reference-api/` and `/dev/orders-api/`.
5. **Browser:** log in once on the presenting laptop (accept the certificate, authorise GitHub).
6. **Pick a new service name** for the live creation (e.g. `payments-api`). It must not exist on GitHub.
7. **Warm-up (optional):** create and tear down one throwaway service, so GitHub runner and
   ECR caches are warm and you've seen every screen that day.

## The script (about 12 minutes)

| # | Time | Show | Live or prepared | Say |
|---|---|---|---|---|
| 1 | 0:00 | Log in with GitHub | Live | Single sign-on, and only people in the catalog can enter. |
| 2 | 0:45 | Catalog: `reference-api`, `orders-api`, filter by owner | Prepared | Every service has an owner, a system, and links. It's the map of your software. |
| 3 | 2:00 | `reference-api` → **Overview**, then **Docs** | Prepared | Documentation lives next to the code and renders here. |
| 4 | 3:00 | **Create** → "Node.js service on AWS ECS (Fargate)", fill in 3 fields, Create | **Live** | This is the golden path: three questions instead of three days of setup. |
| 5 | 3:30 | Result page → **Repository**: Dockerfile, `infra/main.tf`, 10-line `ci-cd.yml` | **Live** | Everything is plain code the team owns. The pipeline logic is shared, so fixes reach every service. |
| 6 | 4:30 | **CI/CD pipeline** link → tests and security scan running in parallel | **Live** (keep running) | Secrets and vulnerabilities are checked on every push, not in a quarterly audit. |
| 7 | 5:30 | While it runs: `orders-api` → **GitHub Actions** tab, **Amazon ECS** tab | Prepared | Same view for every service: build history and what's running in AWS. |
| 8 | 7:00 | Back to the new pipeline: "Log in to AWS with OIDC", Trivy image scan, push, deploy | **Live** | No AWS keys stored anywhere. GitHub gets one-hour credentials limited to your repos. |
| 9 | 9:30 | Open the new service's Dev URL → JSON with `"version":"sha-…"` | **Live** | Every running version maps to an exact commit. |
| 10 | 10:30 | Catalog → the new component: owner, docs, CI and ECS tabs | **Live** | Created, deployed, documented and discoverable, with no tickets. |
| 11 | 11:30 | Wrap-up: the cost slide (below) | – | Runs on ECS Fargate in your AWS account. No Kubernetes to operate. |

### Optional add-on (+4 min): self-service cloud resources

| # | Show | Live or prepared | Say |
|---|---|---|---|
| A | **Create** → "S3 bucket (AWS)" (or PostgreSQL/EC2), fill in name, purpose, owner, "used by" service | **Live** | Developers ask for infrastructure in a form. They don't write Terraform or get console access. |
| B | Result → **Pull request**: generated Terraform (5 lines using a vetted module), then the `terraform plan` comment | **Live** | Every request is code, and the plan shows exactly what will be created before anyone approves. |
| C | Merge (as the platform team) → Actions: *Apply* | **Live** (S3 ≈ 1 min; RDS ≈ 8–10 min, so use S3 live) | Approval is a merge. Only merged code can use the AWS role that creates things. |
| D | Catalog → `rds-orders-db` → *Relations*: `orders-api` depends on it; links to the RDS console + Terraform | Prepared | Every resource has an owner and a consumer, so there's no orphaned infrastructure. |

Guardrails to mention: databases only in private subnets and reachable only from ECS services;
passwords generated into Secrets Manager; S3 private + encrypted + HTTPS-only; EC2 with no SSH
and no open ports (browser shell via Systems Manager); size allow-lists with the cost shown in the form.

**Decommission:** a PR that adds a `DESTROY` file to `resources/<type>/<name>/` and deletes its
`catalog-info.yaml`. The plan shows only deletions; the merge removes it from AWS and the catalog.

**If the pipeline is slow or fails live:** switch to `orders-api`. It went through exactly
the same path; show its green run and its ECS tab.

## After the demo

```bash
cd /opt/backstage/devops94-demo
deploy/scripts/teardown-service.sh payments-api   # asks you to retype the name
```
Then unregister the entity in Backstage and delete (or archive) the GitHub repo, as the
script prints. Never tear down `reference-api` (the script refuses to).

## Cost (ap-south-1, approximate)

| Item | Monthly |
|---|---|
| ALB (shared) | ~$18–20 |
| Each service in dev (Fargate Spot, 0.25 vCPU / 0.5 GB) | ~$3 |
| RDS `orders-db` (db.t4g.micro, 20 GiB) — demo example | ~$15 |
| S3 `idp-demo-files` | ~$0 |
| ECR, CloudWatch Logs, S3 state | < $2 |
| Backstage EC2 (t3.large, existing) | ~$60 |

To pause a service: set `desired_count = 0` in its `infra/main.tf` module call and push.

## Honest answers to likely client questions

| Question | Answer |
|---|---|
| "Is this production-ready?" | The patterns are: OIDC, immutable images, scanning, IaC, rolling deploys with automatic rollback. The demo simplifies hosting: one EC2 for Backstage, HTTP for services (no domain/certificate), public subnets without NAT, dev only. Each has a standard production upgrade (Elastic IP + domain + ACM certificate, private subnets, prod environment with approval, RDS for Backstage). |
| "Why not Kubernetes?" | Most startups don't need to operate a cluster. ECS Fargate gives containers without servers. The same golden-path approach works with EKS + Argo CD when they grow (see `docs/platform-engineering-research.md`). |
| "Can we change the template?" | Yes. It's a folder in Git. Edit, push, and Backstage picks it up. Pipeline changes reach existing services on their next push. |
| "What does the developer need to know?" | Git and their language. Terraform and the pipeline are generated and readable, but they don't need to learn them on day one. |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Login: "redirect_uri mismatch" | Public IP changed | Pre-demo step 1 |
| Create fails at "Create the GitHub repository" | Token expired or missing scope, or repo name exists | Pre-demo step 2; choose another name |
| RDS apply: `InvalidVPCNetworkStateFault ... sufficient capacity` | Instance class not available in the subnet's AZ | Private subnets cover all 3 AZs (`data_availability_zones`); re-run the job |
| Resource PR has no plan comment | Plan role trust or pipeline paths | Check the `resources` workflow run on the PR |
| Pipeline: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | OIDC trust doesn't match the token's `sub` (GitHub immutable subject claims) | Trust is `repo:0019-KDU@112224823/*` in `infra/platform/github-oidc.tf` |
| Pipeline: `AccessDenied ... ecs:<Action>` | New AWS provider feature needs a new permission | Add exactly that action to `infra/platform/github-oidc.tf`, apply |
| ECS tab empty | Service not deployed yet, or ARN annotation wrong | Wait for the pipeline; check `aws.amazon.com/amazon-ecs-service-arn` |
| Docs tab slow the first time | TechDocs builds on first view (cached in /tmp until restart) | Open Docs once before the demo |
