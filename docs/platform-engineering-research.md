# Internal Developer Platform Research

> Research and target architecture for the `devops94-demo` Backstage project.
> Status: **for review — nothing in this document has been implemented yet.**
> Date: 2026-09-23 · Backstage version in this repo: 1.55.0 (new backend + new frontend system)

### How to read the evidence labels

| Label | Meaning |
|---|---|
| **FACT** | Verifiable from official documentation, source code, or a first-party publication. |
| **PRACTICE** | Documented practice: a recommendation published by a project, standards body or company engineering blog. |
| **OPINION** | Engineering opinion: practitioner or vendor commentary. Vendor opinions are marked *(vendor)* because the author sells a competing product. |
| **INTERPRETATION** | Our own synthesis and recommendation for this project. |

Numbers in brackets, e.g. [R1], refer to [§22 References](#22-references).

---

## 1. Executive Summary

1. **A portal is not a platform.** **FACT/PRACTICE**: The CNCF defines a platform as *"an integrated collection of capabilities defined and presented according to the needs of the platform's users"* and lists web portals such as Backstage as **one interface** to those capabilities, alongside APIs, CLIs and templates [R1]. Backstage describes itself as *"an open source framework for building developer portals"* [R7].
2. **Backstage is the front door, catalog and orchestrator of *requests*, not the executor of infrastructure.** **FACT**: Backstage's Kubernetes plugin is read-only (`get/list/watch`) [R11]. The Argo CD plugin reads sync and health state from Argo CD [R14]. The scaffolder runs *actions* that call GitHub and other systems [R10]. Commercial portals are designed the same way: Port *"does not provision infrastructure itself"* and hands actions to GitHub workflows, webhooks and similar systems [R24]. Humanitec positions its orchestrator *behind* any portal [R25].
3. **Golden paths are the product, and templates are only their entry point.** **PRACTICE**: Spotify [R3] and Google Cloud [R4] both define golden paths as opinionated, supported, *optional* routes to production that include docs, CI/CD, IaC, policy and observability, not just a code skeleton.
4. **Adoption is the hard part.** **FACT**: Spotify's head of Backstage engineering put the average *external* adoption rate at about 10%, against about 99% inside Spotify [R6]. **FACT**: DORA 2024 found that internal developer platforms improve individual and team productivity but are associated with *lower* throughput and change stability during adoption [R5].
5. **Recommendation for this project** (**INTERPRETATION**): keep Backstage as the developer-facing layer. Build **one** end-to-end golden path first: *Backstage template → GitHub repo → GitHub Actions (test, Gitleaks, Trivy, build) → GHCR → GitOps repo → Argo CD → Kubernetes → Grafana*, all visible back in Backstage. Terraform self-service, SonarQube, OpenTelemetry tracing, image signing and admission policies come in later phases. The Kubernetes cluster **must not** run on the current EC2 host (3.7 GiB RAM, 80% disk used). That needs an AWS decision from you (§19).

---

## 2. What Is an IDP?

### 2.1 Terms, defined technically

| Term | Technical meaning | Evidence |
|---|---|---|
| **Platform Engineering** | The *discipline* of building and operating internal platforms as products, reducing application teams' cognitive load through self-service. | **PRACTICE** [R1][R2][R40] |
| **Infrastructure Platform** | The runtime substrate: cloud accounts, networks, Kubernetes clusters, databases, IAM. It exposes low-level APIs (AWS APIs, the Kubernetes API). | **INTERPRETATION**, consistent with the CNCF "infrastructure services" capability [R1] |
| **Internal Developer Platform (IDP)** | The *integrated set* of capabilities an application team consumes to build, ship and run software: CI, CD, runtime, data services, identity, observability, security. It also includes the **interfaces** (portal, CLI, API, templates) and the **automation** connecting them. | **PRACTICE**: the CNCF platform definition and capability table [R1] |
| **Developer Portal** | A web UI over the IDP, used for discovery (catalog, docs, ownership) and for *triggering* self-service. It holds metadata and a view of state, not the state itself. | **FACT**: Backstage self-description [R7]; CNCF lists portals as an interface [R1] |
| **Developer Experience (DX) Platform** | An organisational label, not a technical category. Examples: American Airlines brands its Backstage-based portal *"Runway – The Developer Experience Product"* [R36], and Zalando calls Sunrise a "developer platform" [R35]. In practice it usually means *portal + golden paths + the team that runs them*. | **INTERPRETATION** |

### 2.2 Where Backstage fits

```
 ┌──────────────────────────── Internal Developer Platform ──────────────────────────────┐
 │  Interfaces:   Backstage (portal) · CLI · Git (PRs) · APIs · IDE                         │  ← Backstage lives here
 │  ───────────────────────────────────────────────────────────────────────────────────   │
 │  Capabilities: CI · Artifact registry · GitOps CD · IaC · Runtime (K8s) · Secrets      │
 │                Observability · Security scanning · Policy · Identity                   │
 │  ───────────────────────────────────────────────────────────────────────────────────   │
 │  Infrastructure platform: AWS accounts, VPCs, EKS, RDS, IAM                            │
 └────────────────────────────────────────────────────────────────────────────────────────┘
        ▲ Platform Engineering = the team + product practice that builds and runs all of this
```

**INTERPRETATION**: *"We installed Backstage"* means you have built **one interface**. The IDP is everything underneath that the interface can reach.

---

## 3. Production IDP Patterns

These patterns recur across the sources studied (**INTERPRETATION**, each backed by the cited sources):

| # | Pattern | Evidence |
|---|---|---|
| P1 | **Paved road / golden path, optional but better.** Central teams make the supported path the easiest one; teams *may* leave it and lose support. | Netflix "paved road" [R32]; Spotify [R3]; Google Cloud principle "Optional" [R4] |
| P2 | **Abstract infrastructure *details*, not infrastructure *existence*.** Uber's Up moved 4,500 services across clouds with service teams *"largely distanced from the infrastructure detail"* [R33]. Mercado Libre's Fury gives about 16k developers a web UI and CLI over Kubernetes and cloud [R34]. | **FACT** (company blogs) |
| P3 | **Catalog as a system of record for ownership**, synced from sources of truth rather than typed by hand. Zalando syncs more than 40,000 entities daily from source-of-truth services [R35]. | **FACT** |
| P4 | **Distributed plugin ownership.** At Zalando at least ten portal plugins are owned by teams *outside* the portal team, e.g. CD and ML platforms [R35]. American Airlines runs an InnerSource plugin model [R36]. | **FACT** |
| P5 | **Separate CI (build artifacts) from CD (reconcile desired state).** | **PRACTICE**: Argo CD best practices [R17]; OpenGitOps [R16] |
| P6 | **Standards expressed as scorecards/levels** (Bronze/Silver/Gold). | **FACT**: Spotify Soundcheck [R39], Cortex [R27], OpsLevel [R28], Roadie Tech Insights [R29] |
| P7 | **Platform as a product** with a roadmap, user research, adoption metrics and deprecation of legacy tools. Zalando: *"Shut down legacy tooling to drive adoption"* [R35]. | **PRACTICE** [R1][R2][R35] |
| P8 | **Short-lived, federated credentials** between CI and cloud (OIDC), not long-lived keys. | **PRACTICE** [R43] |

---

## 4. Major Platform Approaches

### 4.1 Products and frameworks

| Platform | Category | Architectural model (what it actually *is*) | Evidence |
|---|---|---|---|
| **Backstage** | Portal *framework* (OSS, CNCF) | TypeScript/React app plus a Node backend with plugins. Core: Catalog, Scaffolder, TechDocs, Search, Permissions. You build and operate it yourself. | **FACT** [R7][R8][R10] |
| **Spotify Portal / Soundcheck** | Commercial Backstage offering and plugins | Soundcheck: Checks → Levels → Tracks → Certifications for tech health. | **FACT** [R39] |
| **Roadie** | Hosted (SaaS) Backstage | Runs Backstage for you: upgrades, plugins, Tech Insights scorecards. | **FACT/OPINION** *(vendor)* [R29] |
| **Red Hat Developer Hub** | Supported Backstage *distribution* | Adds **dynamic plugins**, installed without rebuilding the app, plus supported/certified plugin tiers. | **FACT** [R38] |
| **Port** | SaaS portal (not Backstage) | Blueprint → Entity → Relation data model. Self-service actions are **executed by your backends** (GitHub workflows, webhooks, Kafka, etc.). | **FACT** [R23][R24] |
| **Cortex / OpsLevel** | SaaS catalog plus standards | Strongest on scorecards/rubrics: rules evaluated against catalog entities, grouped into levels. | **FACT** [R27][R28] |
| **Humanitec** | Platform *orchestrator* (backend) | Turns a workload spec (Score) plus environment context into resources and config. Portal-agnostic: *"quite common to use other portals… instead of the Humanitec Portal"*. Uses Terraform drivers. | **FACT** [R25][R26] |
| **Score** | Workload spec (CNCF sandbox) | `score.yaml` describes a workload and its dependencies; `score-compose`/`score-k8s` generate concrete manifests. | **FACT** [R26] |
| **Kratix** | Platform *framework* on Kubernetes | "Promises": API + dependencies + provisioning workflows + destination rules. Platform cluster → worker clusters. | **FACT** [R22] |
| **Crossplane** | Control plane for infrastructure APIs | Managed Resources (per provider) + Compositions (function pipelines) define custom APIs. Composite resources are **namespaced** in the current v2.x. | **FACT** [R20][R21] |
| **Mia-Platform** | Commercial platform builder | Console with company/project hierarchy, paved roads, RBAC. Ships a Backstage plugin to import its entities. | **FACT/OPINION** *(vendor)* [R30] |
| **Qovery** | BYOC PaaS on your cloud account | Deploys into *your* EKS/GKE/AKS: git-push deploys, per-PR preview environments. | **FACT/OPINION** *(vendor)* [R31] |
| **Lyft Clutch** | OSS *operations* control plane | Self-service *actions* on infrastructure with RBAC, audit and server-generated forms. An "action" tool, not a catalog. | **FACT** [R37] |

### 4.2 How organisations actually build it

| Organisation | What they built | Uses Backstage? | Evidence |
|---|---|---|---|
| Spotify | Backstage, Golden Paths (since ~2014), Soundcheck | Yes (originator) | **FACT** [R3][R39] |
| Netflix | Paved road + "full cycle developers: operate what you build" | Not as its public core model | **FACT** [R32] |
| Uber | **Up**: multi-cloud control plane for 4,500 stateless services; experience/platform/federation layers | No | **FACT** [R33][R52] |
| Mercado Libre | **Fury**: web UI + CLI over Kubernetes/cloud; ~30k microservices; built since 2015 | No (own platform) | **FACT** (company blog, via [R34]) |
| Zalando | **Sunrise** portal on Backstage (2021); 30 frontend plugins; 40k+ entities | Yes | **FACT** [R35] |
| American Airlines | **Runway** on Backstage (2020); "Create App" golden path; co-authored the Argo CD plugin with Roadie | Yes | **FACT** [R14][R36] |
| Lyft | **Clutch** for safe infra operations | No | **FACT** [R37] |
| Red Hat | Productised Backstage (Developer Hub) | Yes (distribution) | **FACT** [R38] |

Not covered with primary sources in this pass: Google's internal platform, Airbnb, eBay, Capital One and Indeed. Google Cloud's *published golden-path guidance* is used [R4], but we make no claims about Google's internal tooling. These are candidates for a follow-up pass.

**INTERPRETATION**: The largest platforms (Uber, Mercado Libre) built **custom control planes**; their value is the *platform layer*, not the portal. Organisations that chose Backstage (Zalando, American Airlines) used it for the **portal/catalog layer** and still built or integrated the CD, runtime and scoring systems behind it.

---

## 5. Backstage Architecture

### 5.1 What Backstage provides (FACT)

| Capability | What it does | Ref |
|---|---|---|
| Software Catalog | Entities `Component`, `API`, `Resource`, `System`, `Domain`, `User`, `Group`, `Location`, `Template`; relations `ownedBy`, `partOf`, `dependsOn`, `providesApi`, `consumesApi` | [R8] |
| Software Templates (Scaffolder) | Collects parameters, runs *actions* (`fetch:template`, `publish:github`, `catalog:register`, custom actions), with task tracking, dry-run and permissions | [R10] |
| TechDocs | Docs-as-code (MkDocs). Recommended production mode is **docs built in CI, published to object storage (S3), served by Backstage** | [R12] |
| Search | Indexes catalog and TechDocs (this repo uses the Postgres search engine) | repo |
| Permissions | Policy-in-code framework. **Default is allow-all** | [R13] |
| Plugins | Integrations such as the Kubernetes (read-only), Argo CD, GitHub Actions, Grafana and SonarQube views | [R11][R14][R15] |

### 5.2 Which role Backstage should play

| Candidate role | Verdict | Why |
|---|---|---|
| The platform itself | ❌ | Backstage has no runtime, CD engine, IaC engine or secrets store. **FACT** [R7][R1] |
| Frontend / portal | ✅ | Its designed purpose. **FACT** [R7] |
| Software catalog | ✅ | Its core feature, *if* fed from sources of truth. **FACT** [R8]; **PRACTICE** [R35] |
| Self-service interface | ✅ | Templates collect intent and trigger PRs or workflows. **FACT** [R10] |
| Developer experience layer | ✅ | Single pane: ownership, docs, CI, deploys, runtime, dashboards. **INTERPRETATION** |
| Orchestration layer | ⚠️ Only lightweight | The scaffolder can chain actions, but it is a **one-shot task runner**: generated repos become static copies, and propagating template updates is an open problem [R48]. Long-running reconciliation belongs in Argo CD, Terraform or Crossplane. **FACT + INTERPRETATION** |

### 5.3 What stays outside Backstage

```
                       ┌──────────────── Backstage (reads & triggers) ────────────────┐
                       │ Catalog · Templates · TechDocs · Search · Plugin views      │
                       └───┬─────────┬─────────┬─────────┬─────────┬─────────┬───────┘
                           │         │         │         │         │         │
   Source of truth →   GitHub   GH Actions  Argo CD  Kubernetes  Terraform  Grafana/Prom   (+ Vault/Secrets Mgr,
   (owns state)        (repos,  (CI runs)   (desired (runtime)   (infra     (telemetry)     PagerDuty, scanners)
                       teams)               vs live)             state)
```

| Concern | Lives in | Backstage's role |
|---|---|---|
| Code, PRs, CODEOWNERS, branch protection | GitHub | Create the repo (template), show its links |
| Builds, tests, scans | GitHub Actions | Show runs (`github.com/project-slug`) [R9] |
| Deploy state, rollback | Argo CD + GitOps repo | Show sync/health (`argocd/app-name`) [R14] |
| Runtime | Kubernetes | Read-only workload view (`backstage.io/kubernetes-id`) [R11] |
| Cloud resources and state | Terraform (state in S3) | Template opens an infra PR, then links to it |
| Secrets | AWS Secrets Manager / Vault | **Never** store or display secrets |
| Metrics, logs, traces, alerts | Prometheus / Grafana / Loki / Tempo | Links and alert lists (`grafana/*` annotations) [R15] |
| Paging / on-call | PagerDuty / Opsgenie | Show on-call, link incidents |

### 5.4 Known trade-offs of Backstage

- **FACT**: You operate a TypeScript monorepo, rebuild the image to add plugins (outside distributions with dynamic plugins [R38]), and follow a monthly release cadence. This repo is on 1.55.
- **FACT**: Low external adoption (~10%), attributed to setup complexity, plugin selection and a lack of standardisation [R6].
- **OPINION**: Practitioners report 6–12 months to a useful instance and at least one dedicated engineer to keep it healthy [R49][R51]. Some *vendors* argue Backstage is not worth self-hosting [R50] *(vendor, competitor; treat with caution)*.
- **FACT (this repo)**: The app uses the **new frontend system** (`createApp` from `@backstage/frontend-defaults`). Not every community plugin ships a new-frontend-system export yet, so each plugin must be checked before adoption.

---

## 6. Golden Paths

### 6.1 Definitions (PRACTICE)

- Spotify: *"the opinionated and supported path to build something"*. It includes tutorials in TechDocs and blessed tools shown in Backstage, is **optional** (*"you will not have the same support"* if you leave it), and its content is owned by discipline teams [R3].
- Google Cloud (quoting CNCF): *"A templated composition of well-integrated code and capabilities for rapid project development"* [R4]. Nine principles: one clear opinionated way, reduce cognitive load, integrate with the IDP, **complete path to production**, self-service, **transparent abstraction**, fit organisational needs, extensible, **optional** [R4].

### 6.2 What makes one succeed (INTERPRETATION, grounded in [R3][R4][R35][R40])

| Property | Concretely means |
|---|---|
| Complete to production | Template output must deploy on day 1: CI, image, GitOps entry, namespace, dashboards. A skeleton that stops at "repo created" is a template, not a golden path. |
| Opinionated defaults, few inputs | Ask about 5 questions (name, owner, language, optional DB, exposure); everything else defaults. HashiCorp gives the same advice for no-code modules: specific use cases, defaults, dropdowns [R44]. |
| Transparent | Generated files are plain Dockerfile, workflow YAML and Kustomize that developers can read and change [R4]. |
| Guardrails over gates | Security scans and policies run automatically in CI and admission, not as ticket approvals. |
| Owned and versioned | Each golden path has an owning team, a version, and a changelog. |
| Lifecycle (day 2) | Plan for updates from the start: reusable CI workflows referenced by tag (update centrally), base images, and PR-based template updates (cruft/copier-style) [R48]. |
| Documented | A TechDocs tutorial for each path [R3]. |
| Measured | Track template runs, time to first production deploy, and the % of services on the path. |

### 6.3 Golden Path vs its building blocks

| Artifact | Scope | Changes after creation? | Role |
|---|---|---|---|
| **Golden Path** | Whole journey: idea → production → operations | Yes (the product evolves) | The *product* |
| **Backstage Template** | Collects inputs, runs actions once | No: output is a static copy [R48] | *Entry point* |
| **GitHub repository template** | Copies a repo skeleton | No | Simpler alternative to a Backstage template (no inputs or actions) |
| **Reusable CI workflow** (`workflow_call`) | Build/test/scan logic | **Yes**: referenced by tag, updated centrally | The main mechanism for day-2 consistency |
| **Helm chart / Kustomize base** | Kubernetes packaging | Yes, if referenced remotely (versioned) | Runtime contract |
| **Terraform module** | A cloud resource bundle (e.g. RDS + SG + secret) | Yes (versioned) | Infrastructure contract |

**INTERPRETATION**: *Copy* as little as possible into the new repo. *Reference* versioned, centrally owned building blocks (reusable workflows, Kustomize bases or Helm charts, Terraform modules), so improvements reach existing services without regenerating them.

```
Backstage Template  (inputs: name, owner, language, db?, exposure)
   │ fetch:template + publish:github + catalog:register
   ▼
App repo  ── app code · Dockerfile · catalog-info.yaml · mkdocs.yml
   │         .github/workflows/ci.yml  → uses: org/platform-workflows/.github/workflows/build.yml@v1
   │ (template also opens a PR)
   ▼
GitOps repo ── apps/<svc>/base (→ remote Kustomize base @v1) · overlays/dev|staging|prod
   ▼
Argo CD (ApplicationSet picks up apps/*) ──► Kubernetes namespaces
   ▼
Grafana dashboards/alerts (labels: service=<svc>)  ──► linked back in Backstage via annotations
```

---

## 7. Developer Self-Service

### 7.1 The three execution models

| Model | Flow | Strength | Weakness | Evidence |
|---|---|---|---|---|
| **Portal → PR → IaC pipeline** | Backstage template opens a PR in an infra repo; GitHub Actions runs `terraform plan` on the PR and `apply` on merge (OIDC to AWS) | Reviewable, auditable, uses existing Terraform skills | Slower (review); drift is only detected when a plan runs | **PRACTICE** [R43][R44]; **INTERPRETATION** |
| **Portal → Kubernetes API → control plane** | Template commits a Crossplane XR / Kratix resource request to GitOps; the controller reconciles | Continuous reconciliation, K8s-native RBAC and quotas | Must operate Crossplane/Kratix; new abstraction to learn | **FACT** [R20][R21][R22] |
| **Portal → orchestrator/webhook** | Portal calls Port actions, Humanitec, or a custom API | Fast UX | Another system to own; audit depends on the backend | **FACT** [R24][R25] |

HCP Terraform "no-code provisioning" is a fourth option: users provision *"approved collections of resources without learning Terraform"* from a module registry [R44] **(FACT)**. It is commercial.

### 7.2 Typical requests and where they execute (INTERPRETATION)

| Request | MVP mechanism | Later mechanism |
|---|---|---|
| New service | Backstage template → GitHub + GitOps PR | same |
| Namespace + RBAC + quotas | Part of the GitOps overlay (namespace per service/env) | same, enforced by Kyverno |
| PostgreSQL | *Not in MVP* | Template → Terraform module (RDS) PR → Secrets Manager → External Secrets |
| S3 bucket / SQS / Redis | *Not in MVP* | Terraform modules via PR; evaluate Crossplane when there are many requests |
| DNS / TLS | *Not in MVP* (no domain) | external-dns + cert-manager in cluster |
| Service account / cloud IAM | *Not in MVP* | Terraform module (IRSA / EKS Pod Identity) |
| Access requests | Manual (GitHub teams) | GitHub team sync → catalog; approvals via PR |

---

## 8. CI/CD

### 8.1 CI systems: architecture, not ranking (FACT from each project's documented model)

| | GitHub Actions | GitLab CI | Jenkins | Tekton | GoCD |
|---|---|---|---|---|---|
| Definition | YAML in `.github/workflows` | `.gitlab-ci.yml` | `Jenkinsfile` (Groovy DSL) | Kubernetes CRDs (`Task`, `Pipeline`) | Pipelines as code / UI |
| Execution | Hosted or self-hosted runners | Shared or self-hosted runners | Controller + agents, self-managed | Each step runs as a container in a pod | Server + agents |
| Reuse | Reusable workflows, composite actions | `include`, CI/CD components | Shared libraries, plugins | Task catalog / bundles | Templates |
| Cloud auth | OIDC federation to AWS/GCP/Azure [R43] | OIDC ID tokens | Plugins or credentials store | K8s service accounts / workload identity | Plugins |
| Best fit | Code already on GitHub | Code already on GitLab | Existing Jenkins estates, highly custom | Kubernetes-native, CI inside the cluster | Complex value-stream modelling |
| Main cost | Runner minutes; supply chain of third-party actions | Runner ops if self-hosted | Controller/plugin maintenance | Operating the cluster-side CI | Smaller ecosystem |

### 8.2 Why an IDP separates CI from CD (PRACTICE)

1. **Credentials boundary**: with GitOps pull, *"software agents automatically pull the desired state"* [R16], so CI never needs cluster admin credentials.
2. **Audit**: a config-only repo has *"a much cleaner Git history"* [R17].
3. **Different triggers**: you can change manifests *"without triggering an entire CI build"* [R17].
4. **Access control**: developers can have commit access to the app repo but not the config repo [R17].
5. **Rollback** is `git revert` of a desired-state change, with continuous reconciliation [R16].

---

## 9. GitOps

### 9.1 Principles (FACT, OpenGitOps v1.0 [R16])
**Declarative** · **Versioned and immutable** · **Pulled automatically** · **Continuously reconciled**

### 9.2 Argo CD vs Flux (no ranking)

| Aspect | Argo CD | Flux |
|---|---|---|
| Architecture | API server, repo server, application controller [R18] | Separate controllers: source, kustomize, helm, notification, image automation [R19] |
| Reconciliation | Compares live vs target; `OutOfSync` → auto-sync / self-heal; sync hooks [R18] | Each controller reconciles its own CRs (`GitRepository`, `Kustomization`, `HelmRelease`) [R19] |
| Developer experience | Built-in web UI with the resource tree, diff and history, which is useful in demos | No built-in UI in core; CLI- and CR-driven |
| Multi-cluster | Commonly one central Argo CD managing many clusters; `ApplicationSet` generates apps | Commonly Flux per cluster, pulling its own config |
| Security | SSO + RBAC via AppProjects; the central instance holds cluster credentials | Per-cluster, least-privilege; tenancy through service account impersonation |
| Image promotion | External (CI PR, Argo CD Image Updater, Kargo) | Built-in image automation controllers [R19] |
| Backstage integration | Argo CD plugin (sync/health/history) [R14] | Community plugins exist; fewer |

**INTERPRETATION**: Choose **Argo CD** for this project. Its UI is a demo asset, American Airlines and Roadie maintain a Backstage plugin for it [R14], and you listed it as a target.

### 9.3 Repository layout (PRACTICE [R17] + INTERPRETATION)

```
platform-gitops/                       (separate repo; only CI bot + platform team can push to main)
├── bootstrap/            root Argo CD Application (app-of-apps) + ApplicationSets
├── platform/             cluster add-ons: ingress-nginx, kube-prometheus-stack, kyverno (later)
└── apps/<service>/
    ├── base/             kustomization → remote base  github.com/org/platform-k8s-bases//web-service?ref=v1
    └── overlays/
        ├── dev/          image tag = sha-abc123 (auto-updated by CI PR/commit)
        ├── staging/      promoted by PR
        └── prod/         promoted by PR + required review
```
Promotion = a PR that copies an **immutable image digest/tag** from one overlay to the next. Argo CD docs recommend pinning to tags or SHAs rather than `HEAD` [R17]. Rollback = revert that PR.

---

## 10. Infrastructure as Code

| Tool | Model | When | Evidence |
|---|---|---|---|
| Terraform (plan/apply in CI) | Declarative plan → apply; state file | Default for cloud resources; widest provider coverage | **PRACTICE** [R44] |
| HCP Terraform no-code | Module registry + UI inputs | When non-experts must provision without PRs (commercial) | **FACT** [R44] |
| Crossplane | Kubernetes API + controllers, continuously reconciled; custom APIs via Compositions | When you want infrastructure requests as K8s objects via GitOps, with drift correction | **FACT** [R20][R21] |
| Kratix | Promises wrapping any provisioning pipeline, across clusters | Platform-as-a-product framework spanning many teams/clusters | **FACT** [R22] |
| Kubernetes operators | In-cluster lifecycle for one technology (e.g. CloudNativePG) | Data services that live inside the cluster | **INTERPRETATION** |

**INTERPRETATION** for this project:
- Terraform in GitHub Actions with **OIDC** to AWS [R43]: no stored AWS keys.
- Remote state in S3 with native lockfile locking (Terraform ≥ 1.10).
- Versioned modules in a `platform-terraform-modules` repo.
- Crossplane is an *Enterprise-phase evaluation*, not MVP. It doubles the control planes to operate.

---

## 11. Kubernetes

### 11.1 Environment isolation models

| Model | Isolation strength | Cost / ops | Typical use | Evidence |
|---|---|---|---|---|
| Namespaces in one cluster | Soft: needs RBAC, ResourceQuota, NetworkPolicy | Lowest | Dev/test, many small teams | **FACT** [R47] |
| Separate clusters per environment | Strong for control plane and nodes | Higher | Prod separated from non-prod | **FACT** [R47] |
| Separate AWS accounts per environment | Strongest: IAM, billing and quota boundary; *"no access is allowed between accounts"* by default | Needs AWS Organizations / Control Tower | Standard AWS recommendation for prod vs non-prod | **PRACTICE** [R46] |
| Multi-environment GitOps repo | Orthogonal: describes *what* runs where | Low | Used with any of the above | **PRACTICE** [R17] |

**INTERPRETATION**:
- **Demo/MVP**: one small cluster, with namespaces `<svc>-dev`, `<svc>-staging` and `<svc>-prod`, each with quotas and a default-deny NetworkPolicy. Clearly labelled "demo isolation".
- **Production**: non-prod and prod **AWS accounts**, each with its own EKS cluster and one Argo CD per account (or a hub with scoped credentials).

### 11.2 What developers should not need to know
They should not need to know node groups, CNI, ingress controller internals, RBAC YAML or PodSecurity details. The golden path provides a Kustomize base with probes, resource requests, securityContext (non-root, read-only root filesystem), service and ingress. Developers set image, port, env, replicas and resources, which is the same abstraction level Score targets [R26]. **INTERPRETATION**

---

## 12. Security

### 12.1 Where each control belongs

```
 Code ──► PR ──────────► CI build ──────────► Registry ─────► GitOps/Admission ─────► Runtime
 Gitleaks  CodeQL (SAST)   Trivy fs (SCA+IaC)   Trivy image      Kyverno/Gatekeeper      Falco
 (pre-commit Sonar(quality  Syft (SBOM)         re-scan          verifyImages (cosign)   (syscall
  + CI)      + SAST)        Cosign sign+attest                   PodSecurity, policies    detection)
```

| Control | Tool(s) | Stage | Blocks? | Notes / evidence |
|---|---|---|---|---|
| Secret scanning | Gitleaks | pre-commit + CI | Yes on new findings | Plus GitHub push protection where available |
| SAST | CodeQL, SonarQube | PR | CodeQL: high/critical; Sonar: quality gate | CodeQL is free for public repos; private repos need GitHub Advanced Security |
| SCA (dependencies) | Trivy `fs`, Dependabot | PR + scheduled | Critical with a fix available | |
| IaC scanning | Trivy `config` | PR on Terraform / K8s YAML | High | |
| Container scanning | Trivy `image` | CI after build, plus a scheduled re-scan | Critical with a fix | |
| SBOM | Syft (or Trivy `--format cyclonedx`) | CI | No (record) | Attach as an attestation |
| Signing / provenance | Cosign keyless (GitHub OIDC), GitHub artifact attestations | CI | — | SLSA Build L2 = hosted build + **signed provenance** [R41] |
| Admission policy | Kyverno `verifyImages`, PodSecurity, required labels | Cluster admission | Yes | Kyverno checks cosign keyless signatures (subject/issuer) at admission [R42] |
| Runtime detection | Falco | Runtime | Alert | CNCF lists it under security services [R1] |
| Cloud auth from CI | GitHub OIDC → AWS IAM role | CI | — | *"short-lived access token… valid for a single job"* [R43] |
| Portal authorisation | Backstage permission policy | Backstage | Yes | Default is **allow-all** [R13]; this repo currently uses the allow-all module |

**INTERPRETATION**: The MVP enforces **Gitleaks + Trivy (fs, config, image) + OIDC**. It makes SBOMs and signatures *visible*, then enforces them at admission in Phase 2/3. Enforcing admission before signing works everywhere only breaks demos.

---

## 13. Observability

### 13.1 Components (FACT)
- **OpenTelemetry** is an instrumentation and collection standard for traces, metrics and logs, with a Collector to receive, process and export. **It is not a backend** [R45].
- Backends: Prometheus (metrics) + Alertmanager, Loki (logs), Tempo (traces), with Grafana as the UI. The CNCF groups these under "application observability" [R1].

### 13.2 Connecting ownership to telemetry (INTERPRETATION + FACT on annotations)

The join key is **one service identifier** used everywhere:

| Where | Key |
|---|---|
| Catalog | `metadata.name: payments-api`, `spec.owner: team-payments` |
| Kubernetes labels | `app.kubernetes.io/name: payments-api`, `backstage.io/kubernetes-id: payments-api` [R11] |
| OTel resource | `service.name=payments-api`, `service.namespace=<system>`, `deployment.environment=dev` |
| Prometheus / Loki labels | `service="payments-api"`, `namespace="payments-api-dev"` |
| Grafana | dashboard tag `payments-api`; alert label `service=payments-api` |
| Backstage annotations | `grafana/dashboard-selector: "tags @> 'payments-api'"`, `grafana/alert-label-selector: "service=payments-api"` [R15]; `argocd/app-name`, `github.com/project-slug`, `backstage.io/techdocs-ref` [R9][R14] |

```
Backstage Component "payments-api" (owner, system, lifecycle)
 ├─ CI tab          ← GitHub Actions   (github.com/project-slug)
 ├─ CD tab          ← Argo CD          (argocd/app-name)
 ├─ Kubernetes tab  ← K8s API (read)   (backstage.io/kubernetes-id)
 ├─ Dashboards/Alerts ← Grafana        (grafana/dashboard-selector, alert-label-selector)
 ├─ Docs            ← TechDocs         (backstage.io/techdocs-ref)
 └─ Code quality    ← SonarQube        (sonarqube.org/project-key)   [Phase 2]
```

SLOs/SLIs (**INTERPRETATION**): the golden path ships a default availability SLI (non-5xx ratio) and a latency SLI (p95), with burn-rate alerts generated by the Kustomize base (PrometheusRule). Owners adjust the targets.

---

## 14. Service Catalog

### 14.1 Mandatory vs optional metadata

The Backstage descriptor format requires `type`, `lifecycle` and `owner` on a `Component` [R8] **(FACT)**. Everything else below is our policy **(INTERPRETATION)**.

| Field | Mandatory (MVP) | How it's filled |
|---|---|---|
| `metadata.name`, `description` | ✅ | Template |
| `spec.owner` (Group) | ✅ | Template dropdown of Groups (from GitHub team sync in Phase 2) |
| `spec.type` (service, website, library) | ✅ | Template |
| `spec.lifecycle` (experimental → production → deprecated) | ✅ | Template default `experimental` |
| `spec.system` | ✅ | Template dropdown |
| `github.com/project-slug` | ✅ | Template (auto) |
| `backstage.io/techdocs-ref` | ✅ | Template (auto) |
| `backstage.io/kubernetes-id`, `argocd/app-name` | ✅ if deployable | Template (auto) |
| Grafana selectors | ✅ if deployable | Template (auto) |
| `spec.providesApis` / `consumesApis` | Optional → Silver | Developer |
| `dependsOn` (Resources such as the DB) | Auto when the template creates the resource | Template |
| Criticality / tier | Optional → required for prod (custom label, e.g. `tier: 1..3`) | Developer |
| On-call (PagerDuty) | Required for `lifecycle: production` (Phase 3) | Developer |
| SLO link | Silver/Gold | Golden path default |
| Domain | Optional | Architecture team |

**Rule** (**INTERPRETATION**, backed by [R35] and practitioner reports [R49]): anything a machine can fill must be filled by the template or synced, never typed by hand. Stale catalogs are the most-cited adoption killer.

---

## 15. Governance

| Mechanism | MVP | Later |
|---|---|---|
| Ownership | `spec.owner` required; CODEOWNERS generated | Group sync from GitHub org |
| Standards / maturity | Written Bronze criteria in TechDocs | Scorecards: Tech Insights (OSS, community) or Soundcheck (commercial) [R39]. Levels Bronze/Silver/Gold as in Cortex/OpsLevel [R27][R28] |
| Policy | CI gates (Gitleaks/Trivy) | Kyverno admission; Backstage permission policy (replace allow-all) [R13] |
| Audit | Git history (app + GitOps repos), Argo CD history | Centralised audit logs; Backstage auditor service |
| Compliance evidence | CI logs, SBOM artefacts | Signed attestations (SLSA L2) [R41] |
| Cost visibility | — | OpenCost / AWS cost allocation tags per `owner` [R1] |

Proposed **Bronze** level (**INTERPRETATION**): has owner, lifecycle, system, docs; CI passes; no critical CVEs with fixes; image built by the platform workflow.

---

## 16. Platform Team Operating Model

**PRACTICE**:
- CNCF attributes of a platform: *platform as a product, user experience, documentation and onboarding, self-service, reduced cognitive load, optional and composable, secure by default* [R1].
- Team Topologies' **Thinnest Viable Platform**: *"the smallest set of APIs, documentation, and tools needed to accelerate the teams"*. It can be as small as a wiki page [R40].
- Maturity model aspects: Investment, Adoption, Interfaces, Operations, Measurement [R2].

```
Platform team  (product owner + platform engineers)
   │ roadmap · user research · SLOs for the platform · deprecations
   ▼
Internal platform  (golden paths, portal, CI templates, GitOps, clusters)
   │ self-service, docs, office hours, feedback channel
   ▼
Application teams  (own their services end-to-end: "operate what you build" [R32])
```

**How to measure success** (**PRACTICE** [R1] + **INTERPRETATION**):

| Category | Metric |
|---|---|
| Adoption | Monthly active portal users / total engineers; % services on the golden path; template runs per month |
| Speed | Time from "Create service" to first successful deploy in dev (target: < 15 min); time to first prod deploy; onboarding: time to 1st/10th PR |
| DORA | Deployment frequency, lead time, change failure rate, time to restore [R1][R5] |
| Satisfaction | Quarterly developer survey / NPS [R1] |
| Platform reliability | Portal availability, CI queue time, Argo CD sync success rate |
| Toil | Platform tickets per month (should *fall* as self-service grows) |

**Why "product, not tool collection"**: DORA 2024 associates platforms with productivity gains *and* with throughput and stability dips, and the guidance centres on user-centred design and developer independence [R5]. The ~10% external Backstage adoption figure was attributed to teams not identifying the developer problem they were solving [R6]. Tools without product management produce exactly that outcome. **FACT + INTERPRETATION**

---

## 17. Common Failure Patterns

| Anti-pattern | Evidence | Mitigation (INTERPRETATION) |
|---|---|---|
| Portal first, platform never | ~10% adoption; teams stuck at proof of concept [R6] | Build one golden path end-to-end before adding plugins |
| Too many tools / plugins | Difficulty choosing among 150+ plugins cited as a barrier [R6] | Maximum ~6 plugins in MVP, each tied to a demo step |
| Stale catalog | Practitioner reports [R49]; Zalando syncs from sources of truth [R35] | Template- and sync-generated metadata only |
| Dashboards instead of self-service | CNCF maturity: "Scalable" means one-click self-service, not visibility [R2] | Every MVP capability must be *actionable* (create, deploy, promote) |
| Leaky or excessive abstraction | Google's principle of "transparent abstraction" [R4] | Plain Kustomize/YAML the developer can read |
| Mandatory forms / heavy approval | Golden paths are "optional", self-service without tickets [R3][R4] | About 5 inputs; approvals only for prod promotion |
| Platform team becomes a ticket queue | CNCF self-service attribute [R1] | Track tickets per month as a KPI |
| No ownership | Ownership is Backstage's core relation [R8] | `owner` mandatory; CODEOWNERS |
| No documentation | Spotify's golden paths are primarily tutorials [R3] | TechDocs tutorial per golden path |
| Underestimating Backstage maintenance | Practitioner and vendor reports: 6–12 months, dedicated engineer [R49][R51] | Budget upgrade time monthly; consider RHDH/Roadie for clients |
| One-shot templates drift | Open Backstage feature requests [R48] | Reusable workflows + remote bases referenced by version |
| Enforcing before enabling | — | Warn → measure → enforce |

---

## 18. Recommended Architecture

### 18.1 Production IDP reference architecture (INTERPRETATION synthesised from §3–§17)

```
 L1 Developer experience  Backstage: Catalog · Templates · TechDocs · Search · plugin views · permissions
 L2 Self-service          Golden paths (service, DB, bucket…) → PRs / workflow dispatch
 L3 Source control        GitHub: app repos · gitops repo · infra repo · CODEOWNERS · branch protection · rulesets
 L4 CI                    GitHub Actions reusable workflows: test · lint · Gitleaks · Trivy · CodeQL/Sonar · build
 L5 Artifacts             Registry (GHCR→ECR) · SBOM (Syft) · signatures/attestations (Cosign) · scheduled re-scan
 L6 GitOps / CD           Argo CD + ApplicationSets · env overlays · PR promotion · git-revert rollback
 L7 Infrastructure        Terraform modules + CI (OIDC) · S3 state · (Crossplane evaluated later)
 L8 Runtime               EKS per account (non-prod / prod) · namespaces · ingress-nginx or ALB · cert-manager · external-dns
 L9 Security              IAM (OIDC/IRSA) · Secrets Manager + External Secrets · Kyverno · PodSecurity · Falco
 L10 Observability        OTel SDK/Collector · Prometheus/Alertmanager · Loki · Tempo · Grafana · SLO rules
 L11 Governance           Ownership · scorecards · policies · audit (Git, Argo CD, CloudTrail) · cost tags
```

### 18.2 Our target architecture

```
                                   Developer (browser)
                                          │ HTTPS
                     ┌────────────────────▼─────────────────────┐   EC2 #1 (existing, t3.medium)
                     │ Nginx → Backstage (Docker) → PostgreSQL  │   GitHub OAuth sign-in
                     └──┬──────────┬───────────┬───────────┬────┘
        GitHub App      │          │ read      │ read      │ read (links/API)
        (repo create,   ▼          ▼           ▼           ▼
         PRs, org sync) GitHub ── GitHub Actions ── GHCR   Argo CD ── Grafana/Prometheus
                        │ app repos   │ build/scan/push     ▲          ▲
                        │             └─ commit image tag ──┤          │ scrape
                        └─ platform-gitops repo ────────────┘          │
                                                     ┌──────────────────┴───────────────┐
                                                     │ Kubernetes (separate host/cluster)│
                                                     │ ns: <svc>-dev / -staging / -prod │
                                                     └──────────────────────────────────┘
```

### 18.3 Component-by-component

| Component | Decision | Why |
|---|---|---|
| Backstage | Keep (1.55, existing EC2). Add GitHub App integration, one golden-path template, and the GitHub Actions, Argo CD, Kubernetes and Grafana views | Already productionised; its role is the portal [R7] |
| Identity | GitHub OAuth (done). Phase 2: sync GitHub org users/teams to the catalog | Removes the hand-edited `catalog/users.yaml` |
| GitHub integration | **GitHub App**, not a PAT | Scoped, org-installable, not tied to a person (Backstage supports GitHub Apps) |
| Source control | GitHub org with `platform-gitops`, `platform-workflows`, `platform-k8s-bases` and app repos | Separate config repo [R17] |
| CI | GitHub Actions reusable workflow `build.yml@v1` | Centrally updatable golden path |
| Registry | **GHCR** for MVP → ECR in Phase 2 | No AWS resources needed for MVP; ECR once on EKS with IRSA |
| CD | Argo CD + one ApplicationSet over `apps/*/overlays/*` | UI for demo; Backstage plugin [R14] |
| Runtime | **Separate** small cluster (see §19 decision) | This EC2 host lacks RAM and disk |
| Observability | kube-prometheus-stack (Prometheus, Alertmanager, Grafana) in the cluster | Minimum for the demo's "Grafana shows service" step |
| Security | Gitleaks + Trivy in CI (MVP), then SBOM/cosign, Kyverno, SonarQube | Warn → enforce |
| TechDocs | Fix the current `runIn: docker` (no Docker in the prod container). MVP: `runIn: local` with mkdocs in the image, *or* CI-built docs → S3 (recommended [R12]) | The current config cannot build docs in production |
| Permissions | Replace allow-all with a minimal policy (e.g. only owners can unregister entities; scaffolder limited to catalog users) | Default allow-all [R13] |

### 18.4 Developer journey (target)

```
Developer ─► Backstage "Create" ─► Golden Path "Web service"
   inputs: name · owner(team) · language(Node.js | Python*) · database(none | Postgres**) · exposure(internal | public)
   ▼  scaffolder (≈30 s)
   1. repo  org/<name>  (code, Dockerfile, catalog-info.yaml, mkdocs.yml, CODEOWNERS, ci.yml → reusable workflow)
   2. PR/commit to platform-gitops  apps/<name>/{base,overlays/dev,staging,prod}
   3. catalog:register  → Component appears with owner/system/annotations
   ▼  GitHub Actions (≈3–5 min)
   test → gitleaks → trivy fs/config → docker build → trivy image → push ghcr.io/org/<name>:sha-xxxx
   → commit new tag to overlays/dev
   ▼  Argo CD (≈1–3 min)  syncs <name>-dev namespace → Healthy
   ▼  Prometheus scrapes /metrics; Grafana dashboard tagged <name>
   ▼  Backstage Component page: CI ✔ · Argo CD Synced/Healthy · Pods 1/1 · Dashboard link · Docs
   Promotion: PR "promote <name> sha-xxxx to staging/prod" (review required for prod)
 * second language in Phase 2   ** database option in Phase 2 (Terraform)
```

### 18.5 CI architecture
- `platform-workflows/.github/workflows/build.yml` (`on: workflow_call`), versioned by tag.
- Jobs: `test` (language-specific) → `secrets` (Gitleaks) → `sca-iac` (Trivy fs + config, SARIF uploaded to the Security tab) → `build` (Buildx, cache, labels `org.opencontainers.image.source`) → `image-scan` (Trivy image, fail on CRITICAL with a fix) → `push` (GHCR via `GITHUB_TOKEN` with `packages: write`) → `deploy-dev` (commit tag to GitOps with a GitHub App token).
- Phase 2: Syft SBOM + `cosign sign`/`attest` keyless, SonarQube quality gate, CodeQL.

### 18.6 CD / GitOps architecture
- Argo CD installed in-cluster. Root app-of-apps from `platform-gitops/bootstrap`.
- ApplicationSet (git directory generator) over `apps/*/overlays/*` creates `<svc>-<env>` Applications.
- dev: auto-sync + self-heal + prune. staging/prod: auto-sync, changes only via PR (prod requires a CODEOWNERS review).
- Backstage reads Argo CD through the Argo CD backend plugin with a read-only Argo CD account.

### 18.7 Infrastructure architecture
- **MVP**: no Terraform-managed app resources. The cluster itself is built reproducibly, preferably with Terraform, once you approve AWS resources.
- **Phase 2**: `platform-terraform-modules` (rds-postgres, s3-bucket, sqs-queue) plus `platform-infra` repo per environment. A Backstage template opens a PR, Actions runs `plan` (comment) and `apply` on merge via OIDC. Secrets go to Secrets Manager and reach pods through External Secrets.

### 18.8 Security architecture
Covered in §12. MVP gates: Gitleaks and Trivy CRITICAL-with-fix. OIDC everywhere. GitHub App instead of PATs. Replace the Backstage allow-all policy. Branch protection on `platform-gitops` main.

### 18.9 Observability architecture
Covered in §13. MVP: Prometheus + Grafana + one generated dashboard and alert per service. Phase 2: OTel SDK in the templates + Collector → Tempo/Loki. Phase 3: SLO burn-rate alerts → PagerDuty.

### 18.10 Governance architecture
Covered in §15. MVP: mandatory metadata via the template, and a Bronze definition in TechDocs. Phase 2: Tech Insights scorecards.

---

## 19. MVP

### 19.1 Scope

| In MVP | Status today |
|---|---|
| Backstage prod setup (Nginx, TLS, Postgres, GitHub OAuth, backups) | ✅ done |
| GitHub App integration (repo creation, PRs) | ☐ |
| Golden path template "Web service (Node.js)" | ☐ (repo has only the scaffolded example template) |
| Reusable CI workflow: test, Gitleaks, Trivy, build, push GHCR, bump dev tag | ☐ |
| `platform-gitops` repo + Kustomize base + ApplicationSet | ☐ |
| Kubernetes cluster + Argo CD + kube-prometheus-stack | ☐ **needs your AWS decision** |
| Backstage plugins: GitHub Actions, Argo CD, Kubernetes (already installed, needs cluster config), Grafana | ☐ |
| TechDocs fixed for the prod container | ☐ |
| Minimal permission policy | ☐ |

### 19.2 Decision needed: where Kubernetes runs

This EC2 host has **3.7 GiB RAM and 80% disk used**. Argo CD plus kube-prometheus-stack plus workloads realistically need about 4–6 GiB on their own. **INTERPRETATION**: do not co-locate.

| Option | Approx. monthly cost (ap-south-1, on-demand) | Pros | Cons |
|---|---|---|---|
| A. Second EC2 (t3.large/t3.xlarge) running **k3s** | ~$60–120 | Cheap, fast to build, fine for demos | Not EKS; you operate k3s |
| B. **EKS** (1 small managed node group) | ~$73 control plane + nodes (~$60+) | Production-like; IRSA; realistic for clients | Higher cost and setup |
| C. Grow the current EC2 (t3.xlarge, 16 GiB) + k3s alongside Backstage | ~$120 | One host | Mixes portal and runtime; single point of failure |

Recommendation: **A for the demo MVP, B in Phase 2.** Both create AWS resources, so they need your explicit approval. Prices are indicative; check the AWS pricing calculator.

---

## 20. Future Roadmap

| Phase | Adds | Exit criterion |
|---|---|---|
| **MVP** | §19 | New service → running in dev → visible in Backstage in < 15 min, fully automated |
| **Phase 2** | GitHub org/team catalog sync; 2nd language; EKS + ECR (OIDC/IRSA); promotion to staging/prod via PR; Terraform self-service (RDS Postgres, S3); External Secrets; SonarQube quality gate; Syft SBOM + Cosign signing; TechDocs built in CI → S3; OTel instrumentation in templates; real domain + Let's Encrypt | Two golden paths; DB self-service; signed images |
| **Phase 3** | Kyverno (warn → enforce: PodSecurity, required labels, `verifyImages`); Loki + Tempo; SLOs + Alertmanager → PagerDuty; Tech Insights scorecards (Bronze/Silver/Gold); CodeQL; Backstage permission policy by ownership; separate non-prod/prod AWS accounts | Scorecards visible; admission enforcement in non-prod |
| **Enterprise** | AWS Organizations/Control Tower; multi-cluster Argo CD; Falco; cost visibility (OpenCost/tags); Crossplane or Kratix evaluation for self-service at scale; RDS for Backstage (Multi-AZ, PITR); Backstage HA (≥2 replicas behind ALB); consider RHDH/Roadie to cut portal maintenance | Production SLAs for the platform itself |

### What we should NOT implement yet (INTERPRETATION, with reasons)
- **Crossplane / Kratix**: a second control plane to operate before there is demand for infrastructure self-service [R20][R22].
- **Service mesh**: no multi-service traffic requirements yet.
- **SonarQube server** in MVP: heavy (JVM + DB) for this host. Use it in Phase 2 on the cluster, or SonarCloud.
- **Admission enforcement** (Kyverno enforce, image verification) before signing works end-to-end.
- **Multiple languages and many templates**: one excellent golden path beats five partial ones [R6].
- **Custom Backstage plugins**: use existing plugins first; the new frontend system raises migration cost.
- **Multi-account AWS / Control Tower** for the demo.
- **Humanitec/Port/Cortex**: commercial overlap with what Backstage already does for this project. Revisit only for client-specific needs.

### Risks and trade-offs
| Risk | Impact | Mitigation |
|---|---|---|
| Single EC2 for Backstage (no HA), self-signed IP-based TLS | Demo credibility; browser warnings | Elastic IP now; domain + Let's Encrypt in Phase 2 |
| Disk at 80% on EC2 #1 | Builds/backups fail | Prune old Docker images/build cache; grow EBS (needs approval) |
| Backstage upgrade/plugin burden, new-frontend-system compatibility | Slows delivery | Pin versions; upgrade monthly; verify each plugin's `/alpha` (NFS) export before choosing it |
| Template drift after generation | Inconsistent services | Reusable workflows + remote bases by tag [R48] |
| Demo relies on live GitHub Actions and Argo CD timing | Demo stalls | Pre-warm caches; keep a pre-created fallback service (§21) |
| Allow-all permissions | Any signed-in user can do anything | Minimal policy in MVP |
| Throughput/stability dip during adoption | Seen in DORA 2024 [R5] | Measure DORA before/after; keep paths optional |
| Scope creep ("install every tool") | Portal without platform [R6] | Phase exit criteria above |

---

## 21. Client Demo

**Duration**: ~12–14 min. **Principle**: create the new service live; show a pre-existing "reference" service for everything that takes minutes.

| # | Min | Step | Live or preconfigured | What to say (technical point) |
|---|---|---|---|---|
| 1 | 0:00 | Log in with GitHub | Live | SSO; identity resolved to a catalog User via GitHub ID |
| 2 | 0:45 | Catalog: filter by owner/system | Preconfigured data (3–5 services, 2 teams, 1 system) | Ownership graph; the catalog is synced, not typed |
| 3 | 2:00 | Open `reference-api` | Preconfigured, deployed the day before | One page: CI, Argo CD, Kubernetes, dashboards, docs |
| 4 | 3:00 | TechDocs tab | Preconfigured | Docs-as-code next to the service |
| 5 | 4:00 | Create → "Web service" template, 5 inputs | **Live** | Golden path, not a form: defaults and guardrails |
| 6 | 5:00 | Show the created repo, `catalog-info.yaml`, `ci.yml` (one line → reusable workflow), GitOps PR/commit | **Live** | Transparent abstraction; central updates via `@v1` |
| 7 | 5:30 | GitHub Actions run starts: Gitleaks, Trivy | **Live** (runs in background) | Security in the pipeline, not a ticket |
| 8 | 6:30 | *While CI runs*: switch to `reference-api` and show its completed run, Trivy SARIF in the Security tab, GHCR image | Preconfigured | Artifacts, scan results, provenance (Phase 2: signature) |
| 9 | 8:00 | Argo CD UI: `reference-api-dev/-prod` tree, diff, history; show the promotion PR | Preconfigured | Pull-based CD, promotion = PR, rollback = revert |
| 10 | 9:30 | Back to the new service: CI green → dev tag committed → Argo CD syncing → Healthy | **Live** (fallback: pre-created `demo-api-2`) | Zero manual infra steps |
| 11 | 11:00 | Kubernetes tab in Backstage: pods, namespace | Live | Runtime state without kubectl |
| 12 | 12:00 | Grafana dashboard for the new service (templated by label) | Live dashboard, preconfigured template | Observability by default |
| 13 | 13:00 | Backstage page of the new service: everything linked | Live | "One developer-facing view" |

**Preparation checklist**:
- Warm GitHub Actions caches with one run of the template the day before.
- Pre-pull base images on the cluster.
- Pre-create the fallback service.
- Keep the Argo CD refresh interval short (or use a webhook).
- Have a domain + trusted TLS before client demos, because browser warnings undermine trust.
- Delete demo repos after each session (keep a cleanup script, used manually).

---

## 22. References

Accessed 2026-09-23. Links marked † could not be fetched directly in this session (blocked or offline). Their content was taken from search-result summaries or secondary reporting, and should be re-verified before quoting to clients.

| # | Source | Type |
|---|---|---|
| R1 | CNCF TAG App Delivery — *Platforms White Paper* — https://tag-app-delivery.cncf.io/whitepapers/platforms/ | CNCF |
| R2 | CNCF — *Platform Engineering Maturity Model* — https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/ | CNCF |
| R3 | Spotify Engineering — *How We Use Golden Paths to Solve Fragmentation* (2020) — https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/ | Eng. blog |
| R4 | Google Cloud — *Golden paths for engineering execution consistency* (2023) — https://cloud.google.com/blog/products/application-development/golden-paths-for-engineering-execution-consistency | Vendor eng. blog |
| R5 | DORA — *Accelerate State of DevOps Report 2024* — https://dora.dev/research/2024/dora-report/ . The figures +8% individual productivity, +10% team performance, −8% throughput, −14% change stability are widely cited from the full PDF (e.g. https://thenewstack.io/dora-2024-ai-and-platform-engineering-fall-short/ †); the web summary states the effects qualitatively. | Research |
| R6 | TechTarget — *Behind the scenes, Spotify's Backstage a work in progress* (BackstageCon, Nov 2023; Helen Greul, ~10% external adoption) — https://www.techtarget.com/searchitoperations/news/366558592/Behind-the-scenes-Spotify-Backstage-a-work-in-progress | Trade press |
| R7 | Backstage — *What is Backstage?* — https://backstage.io/docs/overview/what-is-backstage | Official docs |
| R8 | Backstage — *System Model* — https://backstage.io/docs/features/software-catalog/system-model ; *Descriptor format* — https://backstage.io/docs/features/software-catalog/descriptor-format | Official docs |
| R9 | Backstage — *Well-known annotations* — https://backstage.io/docs/features/software-catalog/well-known-annotations | Official docs |
| R10 | Backstage — *Software Templates* — https://backstage.io/docs/features/software-templates/ | Official docs |
| R11 | Backstage — *Kubernetes plugin configuration* — https://backstage.io/docs/features/kubernetes/configuration | Official docs |
| R12 | Backstage — *TechDocs architecture* — https://backstage.io/docs/features/techdocs/architecture | Official docs |
| R13 | Backstage — *Permissions overview* — https://backstage.io/docs/permissions/overview | Official docs |
| R14 | Roadie — *Argo CD plugin* (with American Airlines) — https://roadie.io/backstage/plugins/argo-cd/ | Plugin docs |
| R15 | Backstage community Grafana plugin — https://www.npmjs.com/package/@backstage-community/plugin-grafana ; annotation docs https://github.com/K-Phoen/backstage-plugin-grafana/blob/main/docs/dashboards-on-component-page.md | GitHub |
| R16 | OpenGitOps — *Principles v1.0* — https://opengitops.dev/ | CNCF |
| R17 | Argo CD — *Best Practices* — https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/ | Official docs |
| R18 | Argo CD — *Architecture* — https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/ | Official docs |
| R19 | Flux — *Components* — https://fluxcd.io/flux/components/ | Official docs |
| R20 | Crossplane — *What's Crossplane* — https://docs.crossplane.io/latest/whats-crossplane/ | Official docs |
| R21 | Crossplane — *Composite Resources* — https://docs.crossplane.io/latest/composition/composite-resources/ | Official docs |
| R22 | Kratix — *Promise reference* — https://docs.kratix.io/main/reference/promises/intro ; *Kratix and Promises* — https://docs.kratix.io/workshop/writing-a-promise/kratix-and-promises | Official docs |
| R23 | Port — *Software catalog overview* — https://docs.port.io/build-your-software-catalog/overview/ | Vendor docs |
| R24 | Port — *Self-service actions* — https://docs.port.io/actions-and-automations/create-self-service-experiences/ | Vendor docs |
| R25 | Humanitec — *Platform Orchestrator overview* — https://developer.humanitec.com/platform-orchestrator/docs/introduction/overview/ | Vendor docs |
| R26 | Score (CNCF sandbox) — https://score.dev/ | OSS |
| R27 | Cortex — *Scorecards* — https://docs.cortex.io/standardize/scorecards | Vendor docs |
| R28 | OpsLevel — *Getting started with rubrics* — https://docs.opslevel.com/docs/getting-started-with-rubrics | Vendor docs |
| R29 | Roadie — FAQ / Tech Insights — https://roadie.io/faqs/ ; https://devops.com/roadie-adds-scorecard-tool-to-backstage-saas-platform/ | Vendor / press |
| R30 | Mia-Platform — *Console overview* — https://docs.mia-platform.eu/docs/products/console/overview-dev-suite ; Backstage plugin https://github.com/mia-platform/backstage-plugin | Vendor docs |
| R31 | Qovery — *Environments* — https://hub.qovery.com/docs/using-qovery/configuration/environment/ | Vendor docs |
| R32 | Netflix TechBlog — *Full Cycle Developers at Netflix — Operate What You Build* (2018) — https://netflixtechblog.com/full-cycle-developers-at-netflix-a08c31f83249 † ; InfoQ summary https://www.infoq.com/news/2018/06/netflix-full-cycle-developers/ | Eng. blog |
| R33 | Uber — *Up: Portable Microservices Ready for the Cloud* — https://www.uber.com/us/en/blog/up-portable-microservices-ready-for-the-cloud/ | Eng. blog |
| R34 | Mercado Libre — *How Kubernetes became the right fit for Mercado Libre's IDP* — https://medium.com/mercadolibre-tech/how-kubernetes-became-the-right-fit-for-mercado-libres-internal-developer-platform-fb02df289def † ; QCon SF 2024 talk https://qconsf.com/presentation/nov2024/scaling-innovation-noops-how-mercado-libre-manages-30000-microservices-and-25 | Eng. blog / talk |
| R35 | Zalando — *Sunrise: Zalando's developer platform based on Backstage* (2023) — https://engineering.zalando.com/posts/2023/08/sunrise-zalandos-developer-platform-based-on-backstage.html | Eng. blog |
| R36 | American Airlines — *Runway – The Developer Experience Product* — https://tech.aa.com/2021-12-21-runway-pt1/ † ; DX podcast https://getdx.com/podcast/building-a-developer-portal/ | Eng. blog / podcast |
| R37 | Lyft — *Clutch* — https://github.com/lyft/clutch | GitHub |
| R38 | Red Hat — *Developer Hub dynamic plugins* — https://developers.redhat.com/blog/2025/01/17/red-hat-developer-hub-simplifies-backstage-plug-management | Vendor docs |
| R39 | Spotify for Backstage — *Soundcheck* — https://backstage.spotify.com/docs/plugins/soundcheck | Vendor docs |
| R40 | Team Topologies — *What is a Thinnest Viable Platform?* — https://teamtopologies.com/key-concepts-content/what-is-a-thinnest-viable-platform-tvp | Practice |
| R41 | SLSA — *Security levels v1.0* — https://slsa.dev/spec/v1.0/levels | Standard |
| R42 | Kyverno — *Verify images: Sigstore* — https://kyverno.io/docs/policy-types/cluster-policy/verify-images/sigstore/ | Official docs |
| R43 | GitHub — *Security hardening with OpenID Connect* — https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect | Official docs |
| R44 | HashiCorp — *No-code provisioning module design* — https://developer.hashicorp.com/terraform/cloud-docs/no-code-provisioning/module-design | Official docs |
| R45 | OpenTelemetry — *Concepts* — https://opentelemetry.io/docs/concepts/ | Official docs |
| R46 | AWS — *Organizing Your AWS Environment Using Multiple Accounts* (2025) — https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html | Official docs |
| R47 | Kubernetes — *Multi-tenancy* — https://kubernetes.io/docs/concepts/security/multi-tenancy/ | Official docs |
| R48 | Backstage issues on updating generated components — https://github.com/backstage/backstage/issues/14416 , https://github.com/backstage/backstage/issues/31361 ; cruft — https://cruft.github.io/cruft/ | GitHub |
| R49 | Earthly — *Backstage Is at the Peak of Its Hype* — https://earthly.dev/blog/backstage-is-at-peak-hype/ ; Riftmap — *The catalog maintenance trap* — https://riftmap.dev/blog/the-catalog-maintenance-trap/ | Practitioner opinion |
| R50 | Port — *Backstage Is Dead* — https://www.port.io/blog/backstage-is-dead | **Vendor opinion (competitor)** |
| R51 | Spotify for Backstage — PagerDuty on Portal — https://info.backstage.spotify.com/portal-pagerduty | Vendor case study |
| R52 | Uber — *Migrating Uber's Compute Platform to Kubernetes* — https://www.uber.com/blog/migrating-ubers-compute-platform-to-kubernetes-a-technical-journey/ | Eng. blog |

**Research gaps and limits**:
- Reddit is not accessible to the research tooling (`reddit.com` blocks the crawler). Practitioner opinion therefore comes from engineering blogs, conference coverage and GitHub issues rather than Reddit threads.
- Google-internal, Airbnb, eBay, Capital One and Indeed practices were not researched with primary sources in this pass.
- Conference talks are cited through their abstracts or secondary coverage, not full transcripts.
