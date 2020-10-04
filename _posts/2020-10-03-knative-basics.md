---
layout: post
comments: true
title: Knative basics
categories: devops
tags: [kupernetes, knative, serviceless]
toc: true
img_excerpt: assets/2020/10/20201003-knative.svg
---

[Knative](http://knative.org/) (pronounced *kay-nay-tiv*) is built on top of Kubernetes to provide middleware building blocks for modern container-based applications. The rest of this post walk through the basic concepts of Knative.


## Introduction
Knative provides the infrastructure for building, deploying, and managing serverless applications/functions on Kubernetes. It consists of the following components:

- **Build **  Source-to-container build orchestration (now Tekton Pipelines)
- **Serving**  Request-driven compute that can scale from zero to as needed and back
- **Eventing **  Management and delivery of events (i.e. publication, subscription)

![knative]({{ "assets/2020/10/20201003-knative.svg" | absolute_url }}){: .center-image }

It provides this infrastructure through the following Kubernetes CRDs (Custom Resource Definitions):

- **Configuration ** the desired state for the service, both application code and configuration.
- **Revision ** an immutable point-in-time snapshot of application code and configuration.
- **Route ** assigns traffic to the revisions of a service.
- **Service** addresses a use case by combining the previous objects.

![knative-crds]({{ "assets/2020/10/20201003-knative-crds.svg" | absolute_url }}){: .center-image }

The following is an example of resources created by Knative when it is installed on a k8s cluster:

```sh
root@kubernetes:~$ kubectl api-resources | grep knative
NAME                              SHORTNAMES      APIGROUP                           NAMESPACED   KIND
podautoscalers                    kpa             autoscaling.internal.knative.dev   true         PodAutoscaler
builds                                            build.knative.dev                  true         Build
buildtemplates                                    build.knative.dev                  true         BuildTemplate
clusterbuildtemplates                             build.knative.dev                  false        ClusterBuildTemplate
images                            img             caching.internal.knative.dev       true         Image
clusteringresses                                  networking.internal.knative.dev    false        ClusterIngress
configurations                    config,cfg      serving.knative.dev                true         Configuration
revisions                         rev             serving.knative.dev                true         Revision
routes                            rt              serving.knative.dev                true         Route
services                          kservice,ksvc   serving.knative.dev                true         Service
root@kubernetes:~$
```

## Knative Build
[Knative Build](https://github.com/knative/build) provides tools to build containers from code source directly on the k8s cluster. Key features:
- Build can include multiple steps where each step specifies a **Builder**.
- A **Builder** is a type of container image that you create to accomplish any task, whether that's a single step in a process, or the whole process itself.
- The steps in a **Build** can push to a repository.
- A **BuildTemplate** can be used to define reusable templates.
- A **ServiceAccount** is a Kubernetes Secret which is used for authentication.

Knative Build under the hood uses a chain of [init-containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) to implement the build steps where each step runs in its own init-container.

![knative-build]({{ "assets/2020/10/20201003-knative-build.svg" | absolute_url }}){: .center-image }

The following steps form a typical example of using Knative Build:
- Download source code from a repository
- Build a container image from this source
- Push the container image to a container registry
- Deploy the container

This example translate to a Build YAML that could look like this:
```yaml
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: my-build
spec:
  steps:
    - name: start
      image: busybox
      args: ["echo", "starting", "build"]
    - name: download
      image: <downloader-image>
      args: ["git", "pull", "..."]
    - name: build
      image: <builder-image>
      args: ["build-tool", "compile", "..."]
    - name: push
      image: <pusher-image>
      args: ["push-tool", "..."]
```

You can also use a [BuildTemplate](https://github.com/knative/build-templates) to re-use Build steps. For instance, the following build tools that can be used as templates:
- [Kaniko](https://github.com/GoogleContainerTools/kaniko) a tool to build container images from a Dockerfile, inside a container or Kubernetes cluster.
- [Buildpack](https://buildpacks.io/) a Cloud Native project to
transform applications source code into images.
- [Buildkit](https://github.com/moby/buildkit) Docker's toolkit for converting source code to build artifacts.


The following manifest illustrates how to use a **BuildTemplate**, in this case `dockerfile-build-and-push`, to build an image and publish it:

```yaml
apiVersion: build.knative.dev/v1alpha1
kind: Build
metadata:
  name: example-build
spec:
  source:
    git:
      url: git://github.com/<organization>/<repository>.git
      revision: <branch>
  template:
    name: dockerfile-build-and-push
    arguments:
      - name: IMAGE
        value: docker.hub/<organization>/<image>
```

Useful commands:
```
$ kubectl get build <build-name>
$ kubectl describe build <build-name>
$ kubectl get buildtemplates
$ kubectl describe buildtemplate <buildtemplate-name>
```

On a cluster running a Build named `helloworld` we can take a look at its logs as follows:
```
root@kubernetes:~# kubectl get build helloworld
NAME         SUCCEEDED   REASON   STARTTIME   COMPLETIONTIME
helloworld   True                 6m          5m
root@kubernetes:~# kubectl describe build helloworld
Name:         helloworld
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"build.knative.dev/v1alpha1","kind":"Build","metadata":{"annotations":{},"name":"helloworld","namespace":"default"},"spec":{...
API Version:  build.knative.dev/v1alpha1
Kind:         Build
Metadata:
  Creation Timestamp:  2020-10-04T05:05:46Z
  Generation:          12
  Resource Version:    2191
  Self Link:           /apis/build.knative.dev/v1alpha1/namespaces/default/builds/helloworld
  UID:                 431cef88-05ff-11eb-b9e7-42010a840ff2
Spec:
  Generation:            1
  Service Account Name:  default
  Source:
    Git:
      Revision:  master
      URL:       https://github.com/instruqt/helloworld-go.git
  Template:
    Arguments:
      Name:   IMAGE
      Value:  knative.registry.svc.cluster.local/helloworld-go
    Kind:     BuildTemplate
    Name:     docker-build
  Timeout:    10m0s
Status:
  Builder:  Cluster
  Cluster:
    Namespace:      default
    Pod Name:       helloworld-s6pt6
  Completion Time:  2020-10-04T05:06:52Z
  Conditions:
    Last Transition Time:  2020-10-04T05:06:52Z
    Status:                True
    Type:                  Succeeded
  Start Time:              2020-10-04T05:05:46Z
  Step States:
    Terminated:
      Container ID:  docker://47845674a716e719b4888b2255e7a5c64c9b0343ed5784c7a9f3bdd806a24573
      Exit Code:     0
      Finished At:   2020-10-04T05:05:50Z
      Reason:        Completed
      Started At:    2020-10-04T05:05:50Z
    Terminated:
      Container ID:  docker://4209006dbb0475689b3adec8eb3097b55b20f944030a46e9663bb757c3e40f1a
      Exit Code:     0
      Finished At:   2020-10-04T05:05:52Z
      Reason:        Completed
      Started At:    2020-10-04T05:05:51Z
    Terminated:
      Container ID:  docker://b0a07dda22b7588232f2981e7b7a8a7d62bf20c457a6d13742d2ea69144a2656
      Exit Code:     0
      Finished At:   2020-10-04T05:06:50Z
      Reason:        Completed
      Started At:    2020-10-04T05:05:57Z
  Steps Completed:
    build-step-credential-initializer
    build-step-git-source
    build-step-build-and-push
Events:  <none>
```

We can inspect the Build templates available on the cluster as follows:
```
root@kubernetes:~# kubectl get buildtemplates
NAME           AGE
docker-build   6m
root@kubernetes:~# kubectl describe buildtemplate docker-build
Name:         docker-build
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"build.knative.dev/v1alpha1","kind":"BuildTemplate","metadata":{"annotations":{},"name":"docker-build","namespace":"default"...
API Version:  build.knative.dev/v1alpha1
Kind:         BuildTemplate
Metadata:
  Creation Timestamp:  2020-10-04T05:05:46Z
  Generation:          1
  Resource Version:    2002
  Self Link:           /apis/build.knative.dev/v1alpha1/namespaces/default/buildtemplates/docker-build
  UID:                 431a76b1-05ff-11eb-b9e7-42010a840ff2
Spec:
  Generation:  1
  Parameters:
    Description:  Where to publish the resulting image.
    Name:         IMAGE
    Default:      /workspace
    Description:  The directory containing the build context.
    Name:         DIRECTORY
    Default:      Dockerfile
    Description:  The name of the Dockerfile
    Name:         DOCKERFILE_NAME
  Steps:
    Args:
      --dockerfile=${DIRECTORY}/${DOCKERFILE_NAME}
      --destination=${IMAGE}
    Image:  gcr.io/kaniko-project/executor:latest
    Name:   build-and-push
Events:     <none>
root@kubernetes:~#
```

> Note: Knative Build is deprecated in favor of Tekton Pipelines.

## Knative Serving
Knative Serving leverages Kubernetes and Istio to deploy and serve applications and functions. It is usully used for:
- Automatic application scaling up and down to zero
- Routing and network programming for Istio components
- Point-in-time snapshots of deployed code and configuration
- Rapid deployment of serverless workloads

The following pictures depicts the relationship between the CRDs that needs to be created to run a Service on top of Knative:
![knative-crds]({{ "assets/2020/10/20201003-knative-crds-relation.svg" | absolute_url }}){: .center-image }


The following YAML manifest illustrates an example declaration of a Knative Service:
```yaml
apiVersion: serving.knative.dev/v1alpha1
kind: Service
metadata:
  name: my-service
  namespace: default
spec:
  runLatest:
    configuration:
      revisionTemplate:
        spec:
          container:
            image: docker.hub/<organization>/<image>
```

The following YAML manifest illustrates an example declaration of a Route to two revisions of a same Service where each deployed revision will get 50% of the total traffic:
```yaml
apiVersion: serving.knative.dev/v1alpha1
kind: Route
metadata:
  name: blue-green-demo
  namespace: default
spec:
  traffic:
    - revisionName: blue-green-00001
      percent: 50
    - revisionName: blue-green-00002
      percent: 50
```

Some useful commands to work with a Knative service:
```sh
$ kubectl get route
$ kubectl get ksvc
$ kubectl get configuration
```

## Knative Eventing
Knative Eventing provides the following primitives to consume and produce events:
- Event Sources: generate events from different sources (k8s, github, pub/sub, container)
- Channels: buffer between event producers and consumers
- Subscriptions: forward events from channels to services or other channels

![knative-eventing]({{ "assets/2020/10/20201003-knative-eventing.svg" | absolute_url }}){: .center-image }

Knative Eventing's primitives can be composed to create loosely coupled services where:
2. Producers can generate events without need for a consumer to be listening.
3. Consumers can listen to events even before they are produced.
3. New Services can be created without need to modify existent producers or consumers.


Knative currently provides a set Event Sources but you can use others from the community:
- [KubernetesEventSource](https://knative.dev/docs/eventing/samples/kubernetes-event-source/)
- [GitHubSource](https://knative.dev/docs/eventing/samples/github-source/)
- [GcpPubSubSource](https://github.com/google/knative-gcp)
- [ContainerSource](https://knative.dev/docs/eventing/samples/container-source/)

## Resources
- knative concepts on [instruqt](https://play.instruqt.com/public/tracks/knative-concepts)