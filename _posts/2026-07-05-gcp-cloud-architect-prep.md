---
layout: post
comments: true
title: Google Cloud Professional Cloud Architect Certification Preparation Guide
excerpt: A focused preparation guide for the Google Cloud Professional Cloud Architect exam, covering architecture tradeoffs, service selection, Well-Architected principles, and case study strategy.
categories: certification
tags: [gcp,cloud,architecture,certification]
toc: true
img_excerpt:
---

<center><img alt="Professional Cloud Architect Certification" src='https://images.credly.com/size/340x340/images/71c579e0-51fd-4247-b493-d2fa8167157a/image.png' width='300' height='300'></center>

The Google Cloud Professional Cloud Architect exam is less about remembering every product feature and more about making sound architecture decisions under constraints. Most questions describe a business goal, an existing technical environment, a migration pressure, a security requirement, or an operational problem. The right answer is usually the one that satisfies those constraints with the least unnecessary operational burden.

This guide is a condensed preparation plan based on the current [Professional Cloud Architect exam guide](https://services.google.com/fh/files/misc/professional_cloud_architect_exam_guide_english.pdf), the official case studies, and the Google Cloud Well-Architected Framework. It is written for final review: the goal is to help you choose the right service, recognize tradeoffs, and reason through case-study questions.

## Exam mindset

The Professional Cloud Architect exam expects you to think like an architect, not like a product catalog. When two answers both mention valid Google Cloud services, ask:

- Which answer best satisfies the business requirement?
- Which answer reduces operational overhead?
- Which answer meets the security or compliance constraint?
- Which answer avoids over-engineering?
- Which answer is easiest to operate, monitor, and recover?
- Which answer fits the current environment instead of assuming a full rewrite?

The exam guide splits the exam into these areas:

| Area | Approximate weight | What to focus on |
| - | - | - |
| Design and plan cloud solution architecture | 25% | Business requirements, deployment archetypes, migration strategy, data, AI, cost, reliability |
| Manage and provision solution infrastructure | 17.5% | Compute, containers, networking, storage, databases, resource hierarchy, Infrastructure as Code |
| Design for security and compliance | 17.5% | IAM, least privilege, encryption, auditability, network security, regulatory controls |
| Analyze and optimize technical and business processes | 15% | Cost optimization, performance, reliability, operational efficiency |
| Manage implementation | 12.5% | CI/CD, release management, migration waves, validation, rollback |
| Ensure solution and operations reliability | 12.5% | Monitoring, logging, alerting, incident response, DR, backup, SLOs |

## The six Well-Architected pillars

The [Google Cloud Well-Architected Framework](https://cloud.google.com/architecture/framework) is the best mental model for the exam. I use the following phrase to remember the pillars:

> Operate securely, recover reliably, control cost, perform fast, sustain efficiently.

| Pillar | Question to ask | Good answers usually include |
| - | - | - |
| Operational excellence | Can we run this well? | Automation, CI/CD, monitoring, SLOs, runbooks, postmortems |
| Security, privacy, and compliance | Is it protected and auditable? | IAM, service accounts, KMS, Secret Manager, VPC Service Controls, audit logs |
| Reliability | Will it survive failure? | Multi-zone design, backups, DR, health checks, load balancing, tested recovery |
| Cost optimization | Are we paying for value? | Right-sizing, autoscaling, lifecycle policies, committed use discounts, budgets |
| Performance optimization | Is it fast enough? | Correct database, caching, CDN, load balancing, data locality, horizontal scaling |
| Sustainability | Are resources wasted? | Managed services, scale-to-zero, cleanup policies, reduced data movement |

When a question feels ambiguous, run every answer through these pillars. The best option is usually the one that satisfies the explicit requirement while staying balanced across the other pillars.

## Architecture tradeoffs

The exam often tests tradeoffs rather than facts. These patterns appear repeatedly:

| Tradeoff | Prefer | When |
| - | - | - |
| Managed vs. controllable | Cloud Run, App Engine, managed databases | Low operations, fast delivery, autoscaling, reduced patching |
| Managed vs. controllable | Compute Engine, GKE, self-managed software | OS control, custom agents, legacy runtimes, special networking, portability |
| Regional vs. global | Regional services | Lower cost, regional users, data residency, acceptable regional outage risk |
| Regional vs. global | Multi-region or global design | Strict availability, global users, regional outage tolerance |
| Rehost vs. modernize | Compute Engine or VMware Engine | Deadline-driven migration, expiring data center, minimal application change |
| Rehost vs. modernize | Cloud Run, GKE, managed databases | Long-term efficiency, elasticity, reduced operations |
| Simplicity vs. portability | Cloud Run and managed Google services | Google Cloud-native platform with minimal operational load |
| Simplicity vs. portability | GKE and open container patterns | Kubernetes standardization or multi-cloud portability |

## Compute: which service when

Start by asking whether the workload is a VM, a container, a function, a Kubernetes platform, or a legacy migration.

| Requirement | Choose | Reason |
| - | - | - |
| Stateless HTTP container with low operations | Cloud Run | Managed container runtime, request autoscaling, scale to zero |
| Event-driven single-purpose code | Cloud Run functions | Lightweight event handlers and HTTP functions |
| Kubernetes platform or complex microservices | GKE | Kubernetes control plane, service mesh, sidecars, custom orchestration |
| Consistent Kubernetes across cloud and on-prem | GKE Enterprise | Fleet, policy, config, and hybrid management |
| Legacy app requiring OS control | Compute Engine | Custom OS packages, agents, startup scripts, kernel/runtime control |
| VMware estate with minimal migration change | Google Cloud VMware Engine | Fast migration path while preserving VMware operations |
| Simple PaaS-style web app | App Engine | Managed runtime with versioning and traffic splitting |
| Batch or scheduled compute | Batch or Cloud Run jobs | Managed execution without standing infrastructure |
| GPU/TPU training or inference | Vertex AI, GKE GPU, Compute Engine GPU, TPUs | Choose based on control level and operational model |

Shortcut: **Cloud Run for stateless containers, GKE for Kubernetes requirements, Compute Engine for OS control, VMware Engine for fast VMware migration, and GKE Enterprise for hybrid Kubernetes.**

## Storage and databases

Database questions become easier when you identify the data model first: relational, document, wide-column, cache, object, file, or analytical.

| Requirement | Choose | Reason |
| - | - | - |
| Normal relational app | Cloud SQL | Managed MySQL, PostgreSQL, or SQL Server for regional OLTP |
| High-performance PostgreSQL-compatible workload | AlloyDB | PostgreSQL compatibility with higher performance expectations |
| Global relational scale with strong consistency | Spanner | Horizontally scalable relational database with strong consistency |
| Massive low-latency key/value or time-series data | Bigtable | Wide-column data, high throughput, large sparse datasets |
| Serverless document data for mobile/web apps | Firestore | Document model and flexible schema |
| Cache, sessions, hot key/value access | Memorystore | Redis or Memcached-compatible managed cache |
| Analytics, BI, reporting, historical scans | BigQuery | Serverless data warehouse for analytical workloads |
| Object files, media, backups, data lake | Cloud Storage | Durable object storage with lifecycle and storage classes |
| Shared POSIX file system | Filestore | NFS semantics for applications that need file-system behavior |
| VM block storage | Persistent Disk or Hyperdisk | Block storage attached to Compute Engine or GKE nodes |

Shortcut: **Cloud SQL for normal relational, AlloyDB for demanding PostgreSQL, Spanner for global relational consistency, Bigtable for massive low-latency wide-column, Firestore for documents, BigQuery for analytics.**

## Data, analytics, and integration

| Requirement | Choose | Reason |
| - | - | - |
| Event ingestion and fanout | Pub/Sub | Decouples producers and consumers |
| Controlled task execution with rate limits | Cloud Tasks | Retryable task queue with execution control |
| Batch and streaming data processing | Dataflow | Managed Apache Beam pipelines |
| Existing Spark or Hadoop jobs | Dataproc or Serverless Spark | Minimal rewrite for Spark/Hadoop workloads |
| Workflow orchestration with Airflow | Cloud Composer | Managed Airflow |
| Simple service orchestration | Workflows | Calls APIs and services in sequence |
| Change data capture | Datastream | Replicates changes from operational databases |
| Database migration | Database Migration Service | Managed migration for supported sources and targets |
| Data governance and discovery | Dataplex | Govern and manage distributed data |

## Networking

Networking questions are driven by traffic type, reachability, latency, and privacy.

| Requirement | Choose | Reason |
| - | - | - |
| Secure hybrid connectivity over the internet | HA VPN | Encrypted tunnels, lower cost, simpler setup |
| High-bandwidth private hybrid connectivity | Dedicated or Partner Interconnect | Private connectivity with higher throughput |
| Dynamic routing for hybrid links | Cloud Router | BGP route exchange for VPN and Interconnect |
| Private VM outbound internet without public IPs | Cloud NAT | Outbound internet access only |
| Central network shared across projects | Shared VPC | Central network team, separate service projects |
| Private endpoint to producer services | Private Service Connect | Private access to Google, third-party, or internal services |
| Global HTTP(S) application | External Application Load Balancer | Layer 7 global anycast, TLS, CDN, Cloud Armor integration |
| Internal HTTP services | Internal Application Load Balancer | Private layer 7 load balancing inside the VPC |
| UDP or source IP preservation | Passthrough Network Load Balancer | Layer 4 passthrough behavior |
| Edge cache | Cloud CDN or Media CDN | Serve static or media content near users |

Shortcut: **VPN is encrypted over the internet. Interconnect is private high bandwidth. Cloud Router exchanges routes. Cloud NAT is outbound only. Private Service Connect makes service endpoints private.**

## Security and compliance

The security answer is rarely a single product. A good architecture combines identity, data protection, network controls, detection, and auditability.

| Problem | Primary control | Supporting controls |
| - | - | - |
| Too much human access | IAM least privilege | Groups, predefined/custom roles, audit logs |
| Workloads using downloaded keys | Workload Identity Federation or attached service accounts | Disable service account key creation where possible |
| Sensitive data exfiltration | VPC Service Controls | IAM, private access, KMS, audit logs |
| Secrets in code or images | Secret Manager | IAM, rotation, audit logs |
| Customer-managed encryption | Cloud KMS | CMEK-enabled services, key rotation |
| Hardware-backed keys | Cloud HSM | Separation of duties and strict key controls |
| Public web attack surface | Cloud Armor | External Application Load Balancer, WAF rules, rate limiting |
| Security posture visibility | Security Command Center | Asset inventory, findings, vulnerability detection |
| Sensitive data discovery | Sensitive Data Protection | Classification, masking, de-identification |
| Container supply-chain policy | Artifact Registry and Binary Authorization | Build provenance and trusted deployment policies |

Remember the distinction: **IAM controls who can access. VPC Service Controls reduce where sensitive service data can move. KMS controls keys. Secret Manager stores secrets. Cloud Armor protects public applications. Security Command Center finds posture issues.**

## Operations, reliability, and CI/CD

| Requirement | Choose | Reason |
| - | - | - |
| Metrics, dashboards, alerts | Cloud Monitoring | Central visibility into service health |
| Central logs and retention | Cloud Logging | Aggregate app, platform, audit, and VM logs |
| Distributed latency tracing | Cloud Trace | Debug latency across services |
| Error aggregation | Error Reporting | Group and alert on exceptions |
| Build automation | Cloud Build | Managed CI |
| Artifact storage | Artifact Registry | Container and package storage |
| Progressive delivery | Cloud Deploy | Release promotion and rollout control |
| Repeatable infrastructure | Terraform or Infrastructure Manager | Reviewable and repeatable changes |
| Disaster recovery | Backups, snapshots, replicas, tested restore | Tie design to RTO and RPO |

For reliability questions, connect the answer to a measurable target:

- multi-zone for zone failure
- multi-region only when regional outage tolerance is required
- backups plus tested restore, not backups alone
- actionable alerts, SLOs, and runbooks instead of ignored email alerts
- postmortems and automation after incidents

## AI and generative AI topics

The current case studies include generative AI themes. Treat AI as part of an architecture, not a standalone answer.

| Requirement | Choose | Reason |
| - | - | - |
| Managed foundation models | Vertex AI and Gemini models | Managed access, tuning, grounding, deployment, governance |
| Model selection | Model Garden | Google, partner, and open models |
| Enterprise search or RAG | Vertex AI Search | Ground answers in approved enterprise data |
| Retail product discovery | Discovery AI / Vertex AI Search for commerce | Product search, recommendations, conversational commerce |
| Conversational agents | Agent Builder, Dialogflow, Gemini Enterprise agent capabilities | Self-service support and natural language workflows |
| ML pipelines | Vertex AI Pipelines | Repeatable ML workflows |
| AI safety | Model Armor and policy controls | Prompt and response filtering |
| Sensitive AI data | Sensitive Data Protection, IAM, KMS, VPC SC | Protect prompts, grounding data, and outputs |

The common trap is to answer with only an LLM. In exam scenarios, AI usually also needs a data platform, security controls, monitoring, human review, and cost management.

## Case study strategy

The exam includes case-study questions. Do not jump directly to services. Read the case and mark:

1. Business goals
2. Current environment
3. Hard constraints
4. Security and compliance risks
5. Availability and DR requirements
6. Data and AI requirements
7. Operational weaknesses
8. Cost pressure

The current case-study themes are:

| Case study | Main theme | Likely service themes |
| - | - | - |
| Altostrat Media | Media platform modernization with generative AI | Cloud Storage lifecycle, BigQuery, GKE/GKE Enterprise, hybrid connectivity, Vertex AI, Model Armor, Cloud Monitoring |
| Cymbal Retail | Catalog enrichment and conversational commerce | Vertex AI Search / Discovery AI, Gemini, human-in-the-loop review, Dataflow, Datastream, Cloud Run/GKE |
| EHR Healthcare | Healthcare SaaS migration from colocation | GKE or Cloud Run, hybrid connectivity, IAM federation, KMS, VPC SC, Cloud Logging/Monitoring, BigQuery |
| KnightMotives Automotive | Automotive digital transformation and AI platform | Hybrid connectivity, API management, Pub/Sub/Dataflow/BigQuery, Vertex AI, regional controls, SCC, gradual modernization |

### Altostrat Media decision map

Altostrat is a media modernization case. The strongest answers combine content platform reliability, hybrid ingestion, storage cost control, analytics, and governed generative AI.

| Need | Likely answer | Reasoning |
| - | - | - |
| Large media library | Cloud Storage with lifecycle policies or Autoclass | Object storage fits audio, video, documents, and archival content; lifecycle controls cost as media volume grows. |
| Audience and content analytics | BigQuery | BigQuery fits user behavior, content consumption, demographics, trend analysis, and content strategy reporting. |
| Existing Kubernetes plus on-prem Kubernetes need | GKE / GKE Enterprise | GKE handles scalable cloud Kubernetes; GKE Enterprise helps with consistent hybrid fleet management. |
| Hybrid content ingestion | HA VPN or Interconnect with Cloud Router | The case needs secure, high-performance connectivity from on-prem ingestion and archival systems. |
| Modern container CI/CD | Cloud Build, Artifact Registry, Cloud Deploy | Containerized deployments need centralized, repeatable build and promotion workflows. |
| Recommendations, summaries, metadata extraction | Vertex AI / Gemini and managed AI APIs | Managed AI services fit NLP, vision/video, summarization, recommendations, and personalization. |
| Harmful content detection | Model safety controls plus human escalation and audit logs | Detection decisions must be explainable, auditable, and monitored. |
| Natural-language support | Agent Builder or conversational agent with grounded content | Self-service support should use approved content and provide an escalation path. |
| Observability across environments | Cloud Logging, Cloud Monitoring, and Prometheus integration where needed | Unify dashboards and alerts instead of relying on fragmented email-based monitoring. |

### Cymbal Retail decision map

Cymbal is a retail modernization case. The strongest answers focus on product data quality, conversational discovery, reduced manual work, and safe content approval.

| Need | Likely answer | Reasoning |
| - | - | - |
| Product attribute generation | Gemini / Vertex AI with structured validation | Generated attributes must align with the product category and catalog structure. |
| Product image variations and enhancement | Vertex AI image generation or editing workflow with review | Generated images should be approved before publishing. |
| Natural-language product discovery | Vertex AI Search / Discovery AI for commerce | Retail search relevance and natural-language discovery directly support conversion goals. |
| Conversational commerce | Agent tooling integrated with web/mobile and product search | Virtual agents should answer questions, discover products, and hand off when needed. |
| Human-in-the-loop review | Internal review UI and workflow | Associates must approve, reject, or edit AI-generated catalog updates. |
| Legacy SFTP and batch integrations | Storage Transfer, Dataflow, Datastream, Workflows or Composer | Brittle file and ETL processes should become automated, observable, and retryable. |
| Many data stores | Target-by-workload database migration | Do not force MySQL, SQL Server, Redis, and MongoDB into one database service blindly. |
| Reduce call center cost | Conversational agent plus escalation and analytics | Automation can lower routine call volume while preserving human support paths. |
| Security and compliance | IAM, KMS, Secret Manager, audit logs, Security Command Center | Customer and interaction data must be protected and monitored. |

### EHR Healthcare decision map

EHR is a healthcare SaaS migration case. The strongest answers preserve legacy integrations, improve availability and observability, and satisfy compliance.

| Need | Likely answer | Reasoning |
| - | - | - |
| Replace colocation with a scalable platform | GKE or Cloud Run plus managed databases | Containerized apps can move to managed compute while reducing infrastructure administration. |
| Minimum 99.9% availability | Regional multi-zone services and load balancing | Regional high availability commonly satisfies this target without unnecessary global complexity. |
| Legacy insurance interfaces stay on-prem | Hybrid connectivity plus secure API/file integration | Do not migrate systems that the case says will not move now. |
| Secure high-performance on-prem connection | Interconnect or HA VPN with Cloud Router | Choose Interconnect for higher private throughput; HA VPN for simpler lower-bandwidth needs. |
| Active Directory users | Cloud Identity or federation with existing identity | Preserve enterprise identity while applying IAM roles to cloud resources. |
| Consistent logging, retention, alerting | Cloud Logging and Cloud Monitoring | Fix ignored email alerts with actionable policies and dashboards. |
| Provider data ingestion | Pub/Sub, Dataflow, Cloud Healthcare API where standards apply | New provider interfaces should be scalable and observable. |
| Healthcare trend analytics | BigQuery with governed data access | BigQuery fits reports and predictions over provider data. |
| Regulatory compliance | IAM, KMS, VPC Service Controls, audit logs, data classification | Healthcare scenarios require security evidence and data protection. |

### KnightMotives Automotive decision map

KnightMotives is a broad enterprise transformation case. The strongest answers modernize gradually, govern sensitive data, and build a scalable AI/data foundation.

| Need | Likely answer | Reasoning |
| - | - | - |
| Hybrid enterprise modernization | Hybrid connectivity and phased modernization | Mainframe, ERP, and manufacturing systems require gradual replacement. |
| Dealer/customer build-to-order reliability | Modern API-backed services with observability and managed databases | The architecture should improve reliability and transparency for dealers and customers. |
| API integration across dealer, service, vehicle, and corporate systems | Apigee or API management | Enterprise API policy, security, analytics, and lifecycle management matter. |
| Data monetization and insights | BigQuery-centered governed data platform | Siloed corporate, vehicle, dealer, and safety data must be unified for analytics. |
| Autonomous vehicle development | Vertex AI, GPUs/TPUs/AI Hypercomputer, simulation data pipelines | Heavy AI workloads need scalable training and simulation infrastructure. |
| EU data protection | Regional controls, IAM, KMS, VPC Service Controls, audit logs, data minimization | Data residency and privacy constraints affect architecture choices. |
| Past breaches | Security Command Center, Cloud Armor, incident response, IAM hardening | Security posture and response maturity are business requirements. |
| Rural vehicle connectivity | Offline-tolerant design, edge buffering, asynchronous sync | Real-time cloud dependency may fail in rural coverage gaps. |
| Dealer no-budget constraint | Cloud-hosted tools | Avoid requiring dealer-owned hardware refresh. |

### Case-study traps

- Altostrat: do not answer with only an LLM. Include storage lifecycle, data platform, hybrid ingestion, CI/CD, observability, and AI governance.
- Cymbal: do not skip human review. The case explicitly needs associates to approve, reject, or modify generated catalog content.
- EHR Healthcare: do not migrate every legacy insurance integration immediately. The case says some systems remain on-prem for years.
- KnightMotives: do not propose a one-step rewrite of mainframe, ERP, vehicle software, dealer tools, and AI platform. It needs phased modernization.

### Case-study worksheet

Use this worksheet for each case study before looking at answer choices. The purpose is to force the architecture decision out of the case facts, not out of product-name recognition.

| Prompt | What to capture |
| - | - |
| Business goals | Revenue growth, cost reduction, reliability, customer experience, faster onboarding, compliance, or operational efficiency. |
| Current environment | Existing compute, databases, identity systems, monitoring tools, on-prem systems, cloud services, and legacy integrations. |
| Hard constraints | Systems that cannot move yet, no-equipment constraints, regulatory boundaries, availability targets, latency needs, or migration deadlines. |
| Security and compliance risks | Sensitive data, data residency, past breaches, auditability, least privilege, encryption, and exfiltration risks. |
| Availability and DR needs | Required uptime, zone or region failure tolerance, RTO/RPO, backup and restore expectations, and failover strategy. |
| Data and AI needs | Analytics, data ingestion, search, recommendations, summarization, model grounding, human review, and AI safety controls. |
| Best compute choice | Cloud Run, GKE, GKE Enterprise, Compute Engine, VMware Engine, or App Engine, with the reason tied to the case. |
| Best database/storage choice | Cloud SQL, AlloyDB, Spanner, Bigtable, Firestore, BigQuery, Cloud Storage, Filestore, or Memorystore based on the data model. |
| Networking choice | HA VPN, Interconnect, Cloud Router, Shared VPC, Private Service Connect, Cloud NAT, load balancer, or CDN. |
| Operational controls | Cloud Logging, Cloud Monitoring, SLOs, alerts, runbooks, CI/CD, IaC, release strategy, and incident response. |
| Cost controls | Autoscaling, serverless, rightsizing, committed use discounts, storage lifecycle policies, Autoclass, budgets, and labels. |
| One-sentence target architecture | A short sentence that combines the business goal, main services, security controls, and operating model. |

Example target architecture:

> Modernize the customer-facing containerized workloads on GKE or Cloud Run, connect required legacy systems through secure hybrid networking, centralize observability with Cloud Logging and Cloud Monitoring, protect sensitive data with IAM, KMS, audit logs, and VPC Service Controls, and use BigQuery plus Vertex AI services for governed analytics and AI use cases.

## High-Yield Exam Shortcuts

Use these as rapid elimination rules. They are not universal laws, but they match common Professional Cloud Architect scenario patterns.

| If you see | Think first |
| - | - |
| Reduce operations / small team / fast deployment | Managed service or serverless |
| Containerized apps plus Kubernetes standardization | GKE; GKE Enterprise for hybrid or fleet needs |
| Stateless HTTP container with unknown or spiky traffic | Cloud Run |
| Global relational consistency and scale | Spanner |
| Normal relational app | Cloud SQL; AlloyDB for demanding PostgreSQL |
| Analytics and trend reports | BigQuery |
| Low-latency massive key/value or time-series | Bigtable |
| Mobile or web document data | Firestore |
| Growing object or media storage cost | Lifecycle policies, Autoclass, colder storage classes |
| Hybrid low or moderate bandwidth | HA VPN |
| Hybrid high bandwidth or private enterprise connectivity | Interconnect |
| Central network governance across projects | Shared VPC |
| Private endpoint to service producer | Private Service Connect |
| Data exfiltration risk around managed services | VPC Service Controls |
| External CI/CD without keys | Workload Identity Federation |
| Secure access without VPN | Identity-Aware Proxy |
| Ignored email alerts | Cloud Monitoring alerts, SLOs, runbooks, incident process |
| Manual deployments | Cloud Build, Artifact Registry, Cloud Deploy, Infrastructure as Code |
| Product search or conversational commerce | Vertex AI Search / Discovery AI / agent tooling |

## Practice questions

Cover the answer column first. The goal is to practice service selection and rationale, not trivia.

| Question | Answer |
| - | - |
| A team wants to run stateless HTTP containers with very low ops and spiky traffic. | Cloud Run. It provides managed container execution and autoscaling without Kubernetes operations. |
| A SaaS app needs global relational transactions and strong consistency. | Spanner. It is the Google Cloud service for globally scalable relational data with strong consistency. |
| A media company has rapidly growing content objects and wants lower storage cost without losing availability. | Cloud Storage lifecycle policies or Autoclass with appropriate storage classes. |
| Private VMs need outbound internet for updates but must not have public IPs. | Cloud NAT. |
| A retailer needs natural-language product discovery and conversational shopping. | Vertex AI Search / Discovery AI plus conversational agent capabilities. |
| A healthcare company wants to reduce risk of data exfiltration from sensitive managed services. | VPC Service Controls plus IAM, KMS, audit logs, and network controls. |
| An enterprise needs high-throughput private connectivity from on-prem to Google Cloud. | Dedicated or Partner Interconnect with Cloud Router. |
| A platform team wants consistent Kubernetes policy and management across on-prem and cloud. | GKE Enterprise. |
| A pipeline must process both batch and streaming events with minimal ops. | Dataflow. |
| Existing Spark jobs need to move with minimal rewrite. | Dataproc or Serverless Spark. |
| A public web app needs edge WAF and DDoS controls. | External Application Load Balancer plus Cloud Armor. |
| A build pipeline in GitHub needs Google Cloud access without service account keys. | Workload Identity Federation. |
| A team needs controlled retries and rate-limited execution of tasks. | Cloud Tasks, not Pub/Sub. |
| A global static site needs fast delivery. | Cloud Storage backend plus HTTPS load balancing and Cloud CDN. |
| A regulated app needs customer-managed encryption keys. | Cloud KMS; Cloud HSM if hardware-backed key protection is required. |
| A team has many projects but wants central network control and separate application ownership. | Shared VPC. Use a host project for the network and service projects for workloads. |
| A database is relational and normal scale, but the team wants the least operational burden. | Cloud SQL, unless high-performance PostgreSQL or global scale changes the requirement. |
| A PostgreSQL workload has demanding performance requirements and compatibility matters. | AlloyDB. |
| A product catalog search must understand natural-language customer intent. | Vertex AI Search / Discovery AI for commerce. |
| A batch ETL pipeline must become observable, retryable, and scalable. | Dataflow for processing; Composer or Workflows if orchestration is the main requirement. |
| An existing Hadoop/Spark pipeline must migrate quickly with minimal rewrite. | Dataproc or Serverless Spark. |
| A sensitive BigQuery dataset must be protected from exfiltration even by overly broad network paths. | VPC Service Controls with IAM and audit logging. |
| A web app is public and needs WAF rules plus rate limiting. | External Application Load Balancer with Cloud Armor. |
| An internal service needs private HTTP load balancing inside a VPC. | Internal Application Load Balancer. |
| A UDP service needs load balancing and source IP preservation. | Passthrough Network Load Balancer. |
| A company needs private high-bandwidth connectivity to Google Cloud and dynamic routing. | Dedicated or Partner Interconnect with Cloud Router. |
| A company needs a lower-cost encrypted hybrid connection over the internet. | HA VPN. |
| Private services need outbound patch downloads but should not be reachable from the internet. | Cloud NAT for outbound egress; no public VM IPs. |
| Human users need access to a private admin web app without a VPN. | Identity-Aware Proxy with IAM/context-aware controls. |
| A CI/CD system outside Google Cloud must deploy without downloaded service account keys. | Workload Identity Federation. |
| An organization wants to forbid public IPs or restrict deployment regions. | Organization Policy constraints. |
| A team stores API tokens in source control and container images. | Secret Manager with IAM, rotation, and CI/CD injection. |
| A workload requires hardware-backed key protection. | Cloud HSM. |
| Logs are local to VMs and alerts are email-only and ignored. | Cloud Logging, Cloud Monitoring, actionable alert policies, SLOs, and runbooks. |
| A service has backups but nobody has tested restoration. | Define RTO/RPO and perform restore tests; backups alone are insufficient. |
| A media workload has hot and cold objects with changing access patterns. | Cloud Storage Autoclass or lifecycle policies based on observed access. |
| A mobile app needs flexible document data and real-time sync. | Firestore. |
| An IoT/time-series workload needs massive low-latency key-based reads and writes. | Bigtable. |
| A BI dashboard scans large datasets and joins historical business data. | BigQuery, with partitioning/clustering if needed for performance and cost. |
| A service needs cache acceleration but the database remains the source of truth. | Memorystore. |
| A company wants enterprise API policies, analytics, security, and lifecycle management. | Apigee. |
| A simple service-to-service process calls several Google APIs in order. | Workflows. |
| A data team already uses complex Airflow DAGs. | Cloud Composer. |
| Generated retail catalog content must be checked before publication. | Human-in-the-loop review workflow around Vertex AI output. |
| A gen AI answer must use approved enterprise documents rather than general model memory. | Ground the model with Vertex AI Search or approved retrieval sources. |
| AI prompts may contain sensitive data. | Sensitive Data Protection, IAM, KMS, VPC SC, logging controls, and approved data handling. |
| A healthcare SaaS app needs 99.9% availability but not explicit regional outage tolerance. | Regional multi-zone managed design, not necessarily multi-region active-active. |
| A data center lease is expiring soon and workloads are mostly VMware. | Google Cloud VMware Engine or rehost first, then modernize in waves. |
| An app must run the same Kubernetes policy across cloud and on-prem clusters. | GKE Enterprise. |
| A global media service has high latency for static assets. | Cloud CDN or Media CDN in front of the origin. |
| A team needs to analyze billing by team and detect overspend early. | Labels, budgets, alerts, and billing export to BigQuery. |
| A new production environment must be repeatable and reviewable. | Terraform or Infrastructure Manager. |
| A service has a stable compute baseline and predictable growth. | Committed use discounts or reservations after rightsizing. |
| A batch workload can tolerate interruption. | Spot VMs or Batch with retry handling. |
| A regulated workload needs evidence of administrative actions. | Cloud Audit Logs with retention/sinks and review process. |

## Final review checklist

Before the exam, make sure you can explain:

- The six Well-Architected pillars.
- Cloud Run vs. GKE vs. Compute Engine vs. App Engine vs. VMware Engine.
- Cloud SQL vs. AlloyDB vs. Spanner vs. Bigtable vs. Firestore vs. BigQuery.
- Cloud Storage classes, lifecycle policies, and Autoclass.
- HA VPN vs. Interconnect vs. Cloud Router vs. Cloud NAT vs. Private Service Connect.
- External vs. internal load balancers, application vs. network, proxy vs. passthrough.
- IAM, service accounts, Workload Identity Federation, KMS, Secret Manager, VPC Service Controls, Cloud Armor, Security Command Center, and audit logs.
- Pub/Sub vs. Cloud Tasks vs. Dataflow vs. Dataproc vs. Workflows vs. Composer.
- Multi-zone vs. multi-region, backup vs. restore, RTO vs. RPO.
- The core business and technical constraints in each case study.

## Official references

- [Professional Cloud Architect exam guide](https://services.google.com/fh/files/misc/professional_cloud_architect_exam_guide_english.pdf)
- [Professional Cloud Architect certification page](https://cloud.google.com/learn/certification/cloud-architect)
- [Google Cloud Architecture Center](https://cloud.google.com/architecture)
- [Google Cloud Well-Architected Framework](https://cloud.google.com/architecture/framework)
- [Application hosting options](https://cloud.google.com/hosting-options)
- [Google Cloud databases](https://cloud.google.com/products/databases)
- [Cloud Storage classes](https://cloud.google.com/storage/docs/storage-classes)
- [Choosing a load balancer](https://cloud.google.com/load-balancing/docs/choosing-load-balancer)
- [Choosing a network connectivity product](https://cloud.google.com/network-connectivity/docs/how-to/choose-product)
- [IAM overview](https://cloud.google.com/iam/docs/overview)
- [Vertex AI overview](https://cloud.google.com/vertex-ai/docs/start/introduction-unified-platform)

The best use of this guide is not passive reading. Cover the service column in each table and force yourself to pick the service from the requirement. That is much closer to how the exam feels.

---

_I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)._
