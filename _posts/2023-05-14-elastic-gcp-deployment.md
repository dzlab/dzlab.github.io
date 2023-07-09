---
layout: post
comments: true
title: Deploy Elasticsearch on GCP using Terraform
excerpt: Deploy a high available ElasticSearch Cluster on GCP using Terraform
tags: [elasticsearch,gcp]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<img align="center" src="/assets/logos/icons8-google-cloud.svg" width="120" />
<br/>


Elasticsearch is available in GCP marketplace as a fully managed service that makes it easy to deploy, operate, and scale Elasticsearch clusters within Google Cloud platform. With GCP Elasticsearch service, we can create GCP Elasticsearch architecture that suits our application needs at the click of a button. Furthermore, it does provide seamless way for data ingestion; time is saved for monitoring, software patching, backup, failure recovery, and many more benefits that the customers can use.

In this article, instead of going with the few clicks approach, we will use the hard way to deploy a hight-available ElasticSearch on GCP using Terraform.

Our target architecture to host ElasticSearch is a deployed in one dedicated VPC with the following configuration:
- 1 Region
- 2 Availability Zones
- 4 subnets (2 public, 2 private)
- Elasticsearch instances are deployed in the private subnets
- Access to private subnets is nated through the public ones

First, define a [tfvar](https://www.terraform.io/docs/configuration/variables.html) file with the common parts:

```
project_id = "my-project"
region = "us-east1"
```

Next, we set the Terraform provider to GCP and create our dedicated VPC

```
provider "google" {
  project = var.project_id
  region = var.region
}

resource "google_compute_network" "default" {
  name = "my-vpc"
}
```

Next, we create the networking infrastructure: a VPC with 2 subnets in each of 2 availability zones. In each public subnet, a Cloud NAT is created to translate IP addresses of the private subnet.

```
resource "google_compute_subnetwork" "public_us_central1_a" {
  name = "public-us-central1-a"
  network = google_compute_network.default.name
  region = var.region
  ip_cidr_range = "10.0.1.0/24"
}

resource "google_compute_subnetwork" "private_us_central1_a" {
  name = "private-us-central1-a"
  network = google_compute_network.default.name
  region = var.region
  ip_cidr_range = "10.0.2.0/24"
}

resource "google_compute_subnetwork" "public_us_central1_b" {
  name = "public-us-central1-b"
  network = google_compute_network.default.name
  region = var.region
  ip_cidr_range = "10.0.3.0/24"
}

resource "google_compute_subnetwork" "private_us_central1_b" {
  name = "private-us-central1-b"
  network = google_compute_network.default.name
  region = var.region
  ip_cidr_range = "10.0.4.0/24"
}

resource "google_compute_nat" "nat_us_central1_a" {
  name = "nat-us-central1-a"
  network = google_compute_network.default.name
  region = var.region
  subnetwork = google_compute_subnetwork.public_us_central1_a.name
}

resource "google_compute_nat" "nat_us_central1_b" {
  name = "nat-us-central1-b"
  network = google_compute_network.default.name
  region = var.region
  subnetwork = google_compute_subnetwork.public_us_central1_b.name
}
```

Next, to be able to access the Elasticsearch instances we create two cloud routes, one for each private subnet. The routes will point to the Cloud NATs in the respective public subnets. This will allow instances in the private subnets to access the internet through the Cloud NATs.

```
resource "google_compute_route" "private_us_central1_a" {
  name = "private-us-central1-a"
  network = google_compute_network.default.name
  dest_range = "0.0.0.0/0"
  next_hop_gateway = google_compute_nat.nat_us_central1_a.gateway
}

resource "google_compute_route" "private_us_central1_b" {
  name = "private-us-central1-b"
  network = google_compute_network.default.name
  dest_range = "0.0.0.0/0"
  next_hop_gateway = google_compute_nat.nat_us_central1_b.gateway
}
```

Finally, we create the Elasticsearch instances, one in each private subnet. The instances will be configured as a single-node cluster.

```
resource "google_compute_instance" "elasticsearch_us_central1_a" {
  name = "elasticsearch-us-central1-a"
  machine_type = "n1-standard-1"
  zone = "us-central1-a"
  subnetwork = google_compute_subnetwork.private_us_central1_a.name
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = google_compute_network.default.name
    access_config {
      egress {
        egress_rule {
          to_port = 0
          to_addresses = ["0.0.0.0/0"]
        }
      }
    }
  }
  provisioner "remote-exec" {
    inline = ["sudo apt-get update && sudo apt-get install -y elasticsearch"]
  }
}

resource "google_compute_instance" "elasticsearch_us_central1_b" {
  name = "elasticsearch-us-central1-b"
  machine_type = "n1-standard-1"
  zone = "us-central1-b"
  subnetwork = google_compute_subnetwork.private_us_central1_b.name
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = google_compute_network.default.name
    access_config {
      egress {
        egress_rule {
          to_port = 0
          to_addresses = ["0.0.0.0/0"]
        }
      }
    }
  }
  provisioner "remote-exec" {
    inline = ["sudo apt-get update && sudo apt-get install -y elasticsearch"]
  }
}
```

To deploy this infrastructure, group eveyrthing in a single file and run `terraform apply`.

## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
