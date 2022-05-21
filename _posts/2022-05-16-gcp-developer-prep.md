---
layout: post
comments: true
title: GCP Developer Certification Preparation Guide
excerpt: Tips and resources to get ready for passing Google Developer Certification.
categories: certification
tags: [gcp,data,cloud,certification]
toc: true
img_excerpt:
---

<center><img alt="Professional Developer Certification" src='https://badges.images.credential.net/1548352102758.png' width='300' height='300'></center>


I recently passed Google Professional Developer Certification, during the preparation I went throught lot resources about the exam. I also used this [book](https://www.amazon.com/Google-Cloud-Certified-Professional-Developer/dp/1800560990) which is a good read and covers most of the exam topics. It is very good starting point for the preparation if you have little knowledge on Google Cloud services.

> Keep in mind that Google update its services very often, thus any source of information other than the official documentation may become out dated.

The exam is relatively at the same difficulty level of the Data engineer certification exam:
- It is recommended to have at least 3 years of industry experience with at least 1 years using GCP.
- The format of the exam is Multiple choice quesitons, to be finished within 2h.
- You can take the exam in person at a test center.
- One difference, is the exam has 60 questions instead of the typical 50.

The exman focuses on the following areas:
- Storage: block and persistent disks
- Databases: sql and nosql databases, warehousing
- Compute: AppEngine, Compute, kubernetes, functions
- Networking: VPC, data-centers to GCP connections
- DevOps: CI, CD, deployment strategies
- Security: permissions, roles, groups, service accounts, etc.

I could not find a comprehensive resource that covers all aspect of the exam when I started preparing. I had to go over a lot of Google Cloud products page and general Machine Learning resources and at no point I felt ready as both topics are huge. Here I will try to provide a summary of the resources I did found helpful for passing the exam.

## Storage
- https://cloud.google.com/storage/docs/best-practices


- Storage classes https://cloud.google.com/storage/docs/storage-classes

- 

Storage classes for any workload
Save costs without sacrificing performance by storing data across different storage classes. You can start with a class that matches your current use, then reconfigure for cost savings.

|Class | Storage Cost | Access Frequency | Description |
| - | - | - | - |
|Standard | High | Access data frequently | Hot or Frequently accessed data: websites, streaming videos, and mobile apps.|
|Nearline | Low | Access data only once a month | Data stored for at least 30 days, including data backup and long-tail multimedia content.|
|Coldline | Very low | Access data only once a year. | Data stored for at least 90 days, including disaster recovery.|
|Archive | Lowest | | Data stored for at least 365 days, including regulatory archives.|
| Multi-Regional Storage| High | Access data frequently | Equivalent to Standard Storage, except it can only be used for objects stored in multi-regions or dual-regions. |


## Certification SWAG
After passing the exam, you can choose one of the official certification swags:

![developer-certification-swags]({{ "assets/2022/05/20220520-gc-dev-certif-swags.png" | absolute_url }}){: .center-image }

## That's all folks
Check my the following preparation tips for passing other Google certifications:
- Data Engineer certification - [link](https://dzlab.github.io/certification/2021/12/04/gcp-data-engineer-prep/) and
- Machine Learning Engineer certification - [link](https://dzlab.github.io/certification/2022/01/08/gcp-ml-engineer-prep/).

Feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)