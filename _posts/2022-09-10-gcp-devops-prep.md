---
layout: post
comments: true
title: GCP DevOps Certification Preparation Guide
excerpt: Tips and resources to get ready for passing Google DevOps Engineer Certification.
categories: certification
tags: [gcp,cloud,devops,certification]
toc: true
img_excerpt:
---

<center><img alt="Professional DevOps Engineer Certification" src='https://badges.images.credential.net/1548352102758.png' width='300' height='300'></center>

I recently passed Google Professional DevOps Engineer Certification and, while preparing for it, I went through a lot of resources. I had to review the documentation of many Google Cloud products, and at no point did I feel that one source covered everything I needed.

This article summarizes the resources I found helpful for passing the exam, plus the topics I wish I had spent more time reading about.

> Keep in mind that Google updates its services and certification guides very often, so any source other than the official documentation can become outdated quickly. Before booking the exam, always check the current [Professional Cloud DevOps Engineer certification page](https://cloud.google.com/learn/certification/cloud-devops-engineer) and the official [exam guide](https://cloud.google.com/learn/certification/guides/cloud-devops-engineer).

I started my preparation by reading [Google Cloud for DevOps Engineers](https://www.packtpub.com/product/google-cloud-for-devops-engineers/9781839218019). It is a good read even if it is not focused only on the exam. It covers general DevOps practices, particularly SRE practices as recommended by Google, and many Google Cloud services that a DevOps engineer is expected to know.

It is a very good starting point if you have little knowledge of Google Cloud services and DevOps. Google also recommends the [Site Reliability Engineering book](https://sre.google/sre-book/table-of-contents/), and you can find more SRE resources from Google on [sre.google](https://sre.google/).

## Exam at a glance

The exam is close in difficulty to other Google professional certification exams, but the scope is broad because it touches organization setup, infrastructure, CI/CD, SRE, observability, security, and cost optimization.

- Recommended experience: 3+ years of industry experience, including 1+ year designing and managing production systems on Google Cloud.
- Format: 50-60 multiple choice and multiple select questions.
- Duration: two hours.
- Delivery: online-proctored or onsite-proctored at a test center.
- Prerequisites: none.

The current official guide organizes the exam around five areas:

- Bootstrapping and maintaining a Google Cloud organization.
- Building and implementing CI/CD pipelines, including continuous testing, for application, infrastructure, and machine learning workloads.
- Applying site reliability engineering practices.
- Implementing observability practices and troubleshooting issues.
- Optimizing performance and cost.

## Preparation strategy

The most useful preparation path for me was:

1. Read the official exam guide and use it as a checklist.
2. Review the Google Cloud services listed in each domain.
3. Build or at least mentally trace an end-to-end deployment path: source repository, build, artifact storage, deployment, monitoring, alerting, rollback, and cost review.
4. Study SRE concepts separately from product documentation. The exam tests both product knowledge and operational judgment.
5. Practice scenario questions. Most questions are less about memorizing commands and more about choosing the safest, most maintainable, and most Google-recommended option.

If you only read product pages, the preparation can feel endless. Try to connect each product to an operational decision: when to use it, what problem it solves, how it fails, how to secure it, and how to troubleshoot it.

## Organization and environments

You should understand how to bootstrap and maintain a Google Cloud organization for multiple teams and environments.

### Resource hierarchy

Know how organizations, folders, projects, and resources fit together. A common pattern is to separate projects by application and environment, for example `app-dev`, `app-staging`, and `app-prod`, then apply policies at the folder or organization level.

Important topics:

- Resource hierarchy and projects - [link](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy)
- Organization policy constraints - [link](https://cloud.google.com/resource-manager/docs/organization-policy/overview)
- IAM roles, service accounts, and the principle of least privilege - [link](https://cloud.google.com/iam/docs/overview)
- Best practices for enterprise organizations - [link](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations)
- Data residency and resource location constraints - [link](https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations)

For the exam, be comfortable with questions where several answers technically work but only one keeps security, auditability, and future growth under control.

### Networking

DevOps questions can involve network architecture, especially when deployments span many projects or connect to existing environments.

You should know:

- Shared VPC - [link](https://cloud.google.com/vpc/docs/shared-vpc)
- VPC Network Peering - [link](https://cloud.google.com/vpc/docs/vpc-peering)
- Private Service Connect - [link](https://cloud.google.com/vpc/docs/private-service-connect)
- Cloud VPN and Cloud Interconnect - [link](https://cloud.google.com/network-connectivity/docs)
- VPC Flow Logs for troubleshooting - [link](https://cloud.google.com/vpc/docs/flow-logs)

### Infrastructure as code

Infrastructure as code is a major topic. You should know how to automate infrastructure changes, review them, and apply them consistently across environments.

Useful resources:

- Infrastructure Manager - [link](https://cloud.google.com/infrastructure-manager/docs)
- Terraform on Google Cloud - [link](https://cloud.google.com/docs/terraform)
- Cloud Foundation Toolkit - [link](https://cloud.google.com/foundation-toolkit)
- Config Connector - [link](https://cloud.google.com/config-connector/docs/overview)
- Google Cloud architecture blueprints - [link](https://cloud.google.com/architecture#blueprints)

For the exam, remember that infrastructure changes should be versioned, reviewed, automated, and observable. Avoid answers that rely on manual console changes for repeatable production operations.

### Development environments

You may see questions about creating secure and repeatable development environments. Know the purpose of:

- Cloud Workstations - [link](https://cloud.google.com/workstations/docs)
- Cloud Shell - [link](https://cloud.google.com/shell/docs)
- Cloud SDK - [link](https://cloud.google.com/sdk/docs)
- Gemini Code Assist and Gemini Cloud Assist - [link](https://cloud.google.com/products/gemini)

The important idea is that developers should get the right tools and access without manually provisioning insecure or inconsistent machines. For AI-assisted development and operations, understand where these tools can help with code, logs, metrics, and troubleshooting, but do not use them as a substitute for knowing the underlying platform.

## CI/CD

CI/CD is one of the biggest parts of the exam. You need to understand the full path from source code to a safely deployed production workload.

### Cloud Build

Cloud Build is Google Cloud's managed CI service. You should understand build triggers, build configuration files, private pools, substitutions, service accounts, and logs.

Useful resources:

- Cloud Build overview - [link](https://cloud.google.com/build/docs/overview)
- Build configuration files - [link](https://cloud.google.com/build/docs/build-config-file-schema)
- Build triggers - [link](https://cloud.google.com/build/docs/triggers)
- Private pools - [link](https://cloud.google.com/build/docs/private-pools/private-pools-overview)
- Cloud Build service accounts - [link](https://cloud.google.com/build/docs/cloud-build-service-account)

Good to know: Cloud Build steps share a workspace. This can be useful for passing generated artifacts, test reports, or deployment metadata between steps.

### Artifact Registry

Artifact Registry is used to store and manage build artifacts such as container images and language packages.

You should know:

- Artifact Registry overview - [link](https://cloud.google.com/artifact-registry/docs/overview)
- Repository formats - [link](https://cloud.google.com/artifact-registry/docs/repositories)
- Access control - [link](https://cloud.google.com/artifact-registry/docs/access-control)
- Vulnerability scanning with Artifact Analysis - [link](https://cloud.google.com/artifact-analysis/docs)

Expect questions that combine Artifact Registry with Cloud Build, Cloud Deploy, vulnerability scanning, Binary Authorization, and IAM.

### Cloud Deploy

Cloud Deploy is Google Cloud's managed continuous delivery service. It helps define delivery pipelines and promote releases through targets such as staging and production.

Read:

- Cloud Deploy overview - [link](https://cloud.google.com/deploy/docs/overview)
- Delivery pipelines and targets - [link](https://cloud.google.com/deploy/docs/config-files)
- Deployment strategies - [link](https://cloud.google.com/deploy/docs/deployment-strategies)
- Skaffold with Cloud Deploy - [link](https://cloud.google.com/deploy/docs/using-skaffold)

The exam can ask you to choose between rebuilding an artifact per environment and promoting the same artifact through environments. In most production pipelines, you want to build once, store the artifact, then promote that artifact through controlled stages.

### Deployment strategies

Know the trade-offs between common deployment strategies:

| Strategy | When it is useful | Main trade-off |
| - | - | - |
| Rolling deployment | Gradually replace old instances with new ones | Simple, but rollback can be slower |
| Blue/green deployment | Keep old and new versions separate | Safer rollback, but needs extra capacity |
| Canary deployment | Send a small amount of traffic to the new version first | Requires good metrics and traffic control |
| Traffic splitting | Shift percentages of traffic between versions | Useful for gradual rollout and A/B testing |
| Feature flags | Decouple deploy from release | Requires application-level flag management |

Useful resources:

- Application deployment and testing strategies - [link](https://cloud.google.com/architecture/application-deployment-and-testing-strategies)
- Cloud Run rollouts and traffic migration - [link](https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration)
- App Engine traffic splitting - [link](https://cloud.google.com/appengine/docs/standard/splitting-traffic)
- GKE deployment strategies - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/deployment)

### Secrets and configuration

Do not put secrets in source code, build logs, or container images. Know how to separate build-time and runtime configuration.

Important services and topics:

- Secret Manager - [link](https://cloud.google.com/secret-manager/docs)
- Parameter Manager - [link](https://cloud.google.com/secret-manager/parameter-manager/docs/overview)
- Cloud Key Management Service - [link](https://cloud.google.com/kms/docs)
- Certificate Manager - [link](https://cloud.google.com/certificate-manager/docs)
- Workload Identity Federation - [link](https://cloud.google.com/iam/docs/workload-identity-federation)
- GKE Workload Identity Federation - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)

For exam answers, prefer short-lived credentials, workload identity, secret managers, and least-privilege service accounts over long-lived keys.

### Securing the supply chain

You should understand the security controls around CI/CD:

- Artifact Analysis and vulnerability scanning - [link](https://cloud.google.com/artifact-analysis/docs)
- Binary Authorization - [link](https://cloud.google.com/binary-authorization/docs)
- Software supply chain security - [link](https://cloud.google.com/software-supply-chain-security/docs)
- SLSA framework - [link](https://slsa.dev/)
- Cloud Audit Logs - [link](https://cloud.google.com/logging/docs/audit)

The general pattern is to build from trusted source, produce signed or verifiable artifacts, scan them, store them in Artifact Registry, enforce policy before deployment, and keep audit logs.

### Machine learning pipelines

The current exam guide also mentions CI/CD for machine learning workloads. You do not need to become a machine learning engineer for this exam, but you should understand how ML delivery differs from application delivery: model artifacts, data validation, training pipelines, approval gates, evaluation metrics, and rollback plans matter.

Useful resources:

- Vertex AI Pipelines - [link](https://cloud.google.com/vertex-ai/docs/pipelines/introduction)
- MLOps continuous delivery and automation pipelines - [link](https://cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning)
- Cloud Build for machine learning workflows - [link](https://cloud.google.com/build/docs/building/build-ml)

## Compute and runtime platforms

The DevOps exam is not just about CI/CD tools. You also need to know how applications run on Google Cloud and how operational decisions differ by platform.

### Cloud Run

Cloud Run is a serverless container platform. It is a good fit when you want to run containers without managing clusters.

- Cloud Run overview - [link](https://cloud.google.com/run/docs/overview/what-is-cloud-run)
- Services, jobs, and worker pools - [link](https://cloud.google.com/run/docs/resource-model)
- Autoscaling - [link](https://cloud.google.com/run/docs/about-instance-autoscaling)
- Traffic management - [link](https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration)

### Google Kubernetes Engine

GKE is a managed Kubernetes service. It appears often in DevOps scenarios because many CI/CD, security, autoscaling, and observability questions involve Kubernetes.

- GKE overview - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview)
- Autopilot and Standard clusters - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- Cluster autoscaler - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler)
- Horizontal Pod autoscaling - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/horizontalpodautoscaler)
- Fleet management - [link](https://cloud.google.com/kubernetes-engine/fleet-management/docs)
- Troubleshooting GKE - [link](https://cloud.google.com/kubernetes-engine/docs/troubleshooting)

### Compute Engine

Compute Engine still matters for workloads that need VM-level control.

- Managed instance groups - [link](https://cloud.google.com/compute/docs/instance-groups)
- Autoscaling managed instance groups - [link](https://cloud.google.com/compute/docs/autoscaler)
- Startup scripts - [link](https://cloud.google.com/compute/docs/instances/startup-scripts)
- Spot VMs - [link](https://cloud.google.com/compute/docs/instances/spot)

Know when a managed instance group, Cloud Run service, or GKE workload is the better operational fit.

## Site reliability engineering

The DevOps certification has a strong SRE flavor. You should be comfortable with reliability concepts and how they influence engineering decisions.

### SLIs, SLOs, SLAs, and error budgets

These are core concepts:

- SLI: what you measure, for example request success rate or latency.
- SLO: the reliability target, for example 99.9% successful requests over 30 days.
- SLA: the external commitment to customers.
- Error budget: the amount of unreliability you can tolerate before slowing risky changes.

Read:

- SRE book: Service Level Objectives - [link](https://sre.google/sre-book/service-level-objectives/)
- SRE workbook: Implementing SLOs - [link](https://sre.google/workbook/implementing-slos/)
- Cloud Monitoring SLOs - [link](https://cloud.google.com/stackdriver/docs/solutions/slo-monitoring)
- Cloud Service Mesh SLOs and service telemetry - [link](https://cloud.google.com/service-mesh/docs)

Exam questions often ask what to do when reliability is below target. The safest answer usually reduces risk: pause risky releases, roll back, add capacity, reduce blast radius, or improve observability before continuing.

### Capacity and lifecycle management

Know how to plan for quotas, limits, reservations, autoscaling, upgrades, and retirement.

Useful resources:

- Quotas and limits - [link](https://cloud.google.com/docs/quotas)
- Compute Engine reservations - [link](https://cloud.google.com/compute/docs/instances/reservations-overview)
- Cloud Run autoscaling - [link](https://cloud.google.com/run/docs/about-instance-autoscaling)
- GKE cluster autoscaler - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler)
- GKE upgrades - [link](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-upgrades)

### Incident response

You should know the operational response options when users are affected:

- Roll back a bad release.
- Drain or redirect traffic.
- Add capacity.
- Disable a risky feature flag.
- Use logs, metrics, and traces to identify the failing layer.
- Write a postmortem and improve the system.

Read:

- SRE book: Managing Incidents - [link](https://sre.google/sre-book/managing-incidents/)
- SRE book: Postmortem Culture - [link](https://sre.google/sre-book/postmortem-culture/)

## Observability and troubleshooting

Observability is another large part of the exam. You should understand logs, metrics, traces, dashboards, alerts, and how to use them together.

### Logs

Know how Cloud Logging collects, stores, filters, routes, excludes, and exports logs.

Important topics:

- Cloud Logging overview - [link](https://cloud.google.com/logging/docs)
- Logs Explorer - [link](https://cloud.google.com/logging/docs/view/logs-explorer-interface)
- Logging query language - [link](https://cloud.google.com/logging/docs/view/logging-query-language)
- Log routing and sinks - [link](https://cloud.google.com/logging/docs/routing/overview)
- Log exclusions and cost controls - [link](https://cloud.google.com/logging/docs/exclusions)
- Cloud Audit Logs - [link](https://cloud.google.com/logging/docs/audit)
- Sensitive data protection in logs - [link](https://cloud.google.com/sensitive-data-protection/docs/redacting-sensitive-data)

You should also know when to route logs to BigQuery, Pub/Sub, or Cloud Storage for analysis, downstream processing, or long-term retention.

### Metrics, dashboards, and alerts

Cloud Monitoring is central to SRE and troubleshooting questions.

- Cloud Monitoring overview - [link](https://cloud.google.com/monitoring/docs)
- Metrics Explorer - [link](https://cloud.google.com/monitoring/charts/metrics-explorer)
- Alerting policies - [link](https://cloud.google.com/monitoring/alerts)
- Dashboards - [link](https://cloud.google.com/monitoring/dashboards)
- PromQL in Cloud Monitoring - [link](https://cloud.google.com/monitoring/promql)
- Google Cloud Managed Service for Prometheus - [link](https://cloud.google.com/stackdriver/docs/managed-prometheus)
- Cloud Service Mesh observability - [link](https://cloud.google.com/service-mesh/docs/observability)

Make sure you understand alert quality. A good alert should be actionable, tied to user impact or an SLO, and routed to the right team.

### Traces and telemetry

Know when tracing helps and how it complements logs and metrics.

- Cloud Trace overview - [link](https://cloud.google.com/trace/docs/overview)
- OpenTelemetry on Google Cloud - [link](https://cloud.google.com/stackdriver/docs/instrumentation/opentelemetry)
- Correlating logs and traces - [link](https://cloud.google.com/trace/docs/trace-log-integration)

Distributed tracing is especially useful when latency or errors involve many services.

### Ops Agent and hybrid workloads

Know the role of the Ops Agent for Compute Engine and hybrid workloads.

- Ops Agent overview - [link](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent)
- Installing the Ops Agent - [link](https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent/installation)

### Troubleshooting approach

For scenario questions, work from symptom to scope:

1. Is the issue global or limited to a region, version, user segment, or dependency?
2. Did it start after a deployment, config change, quota change, traffic spike, or dependency failure?
3. What do logs say?
4. What do metrics say?
5. What do traces say?
6. Can you mitigate user impact before finding root cause?

The exam often rewards mitigation first, then root-cause analysis.

## Performance and cost optimization

The last domain combines performance engineering and FinOps. You should know how to collect performance data, use recommenders, and choose cost-effective infrastructure.

### Performance

Useful topics:

- Application performance monitoring - [link](https://cloud.google.com/monitoring/docs)
- Cloud Trace - [link](https://cloud.google.com/trace/docs)
- Cloud Profiler - [link](https://cloud.google.com/profiler/docs)
- Active Assist - [link](https://cloud.google.com/products/active-assist)
- Recommenders - [link](https://cloud.google.com/recommender/docs)

Questions may ask how to diagnose latency, right-size workloads, or identify bottlenecks. Prefer answers that use measured data rather than guessing.

### Cost

Know the common cost levers:

- Budgets and alerts - [link](https://cloud.google.com/billing/docs/how-to/budgets)
- Cost table and reports - [link](https://cloud.google.com/billing/docs/how-to/reports)
- Labels for cost allocation - [link](https://cloud.google.com/resource-manager/docs/creating-managing-labels)
- Committed use discounts - [link](https://cloud.google.com/docs/cuds)
- Sustained use discounts - [link](https://cloud.google.com/compute/docs/sustained-use-discounts)
- Spot VMs - [link](https://cloud.google.com/compute/docs/instances/spot)
- Network Service Tiers - [link](https://cloud.google.com/network-tiers/docs/overview)

Do not forget observability costs. Logs, metrics, and traces are valuable, but high-cardinality metrics, noisy logs, and unnecessary retention can become expensive. Know how to use filters, exclusions, sampling, and routing.

## Topics worth extra review

These are topics I would spend extra time on:

- SLOs, SLIs, SLAs, and error budgets.
- Cloud Build, Artifact Registry, and Cloud Deploy working together.
- Deployment strategies and rollback decisions.
- Secret handling and Workload Identity Federation.
- Binary Authorization, vulnerability scanning, and supply chain security.
- Cloud Logging sinks, exclusions, and audit logs.
- Cloud Monitoring alert policies and SLO monitoring.
- OpenTelemetry and Cloud Trace.
- GKE autoscaling and upgrades.
- Cost controls, labels, budgets, recommenders, and committed use discounts.

## Practice resources

Useful preparation resources:

- Official Professional Cloud DevOps Engineer certification page - [link](https://cloud.google.com/learn/certification/cloud-devops-engineer)
- Official exam guide - [link](https://cloud.google.com/learn/certification/guides/cloud-devops-engineer)
- Google Cloud Skills Boost path - [link](https://www.cloudskillsboost.google/paths/20)
- Official sample questions - [link](https://docs.google.com/forms/d/e/1FAIpQLSdpk564uiDvdnqqyPoVjgpBp0TEtgScSFuDV7YQvRSumwUyoQ/viewform)
- Preparing for Google Cloud Certification: Cloud DevOps Engineer Professional Certificate - [link](https://www.coursera.org/professional-certificates/sre-devops-engineer-google-cloud)
- Site Reliability Engineering book - [link](https://sre.google/sre-book/table-of-contents/)
- Site Reliability Workbook - [link](https://sre.google/workbook/table-of-contents/)
- Google Cloud Architecture Framework - [link](https://cloud.google.com/architecture/framework)

## Certification SWAG

After passing the exam, you can choose one of the official certification swags:

## That's all folks

Check the following preparation tips for passing other Google certifications:

- Data Engineer certification - [link](https://dzlab.github.io/certification/2021/12/04/gcp-data-engineer-prep/)
- Machine Learning Engineer certification - [link](https://dzlab.github.io/certification/2022/01/08/gcp-ml-engineer-prep/)
- Cloud Developer certification - [link](https://dzlab.github.io/certification/2022/05/16/gcp-developer-prep/)

Feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)
