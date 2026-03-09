# Hands-on Kubernetes-08-extra: Helm Chart Repository

The purpose of this hands-on training is to give students the knowledge of creating chart repository.

## Learning Outcomes

At the end of this hands-on training, students will be able to;

- Learn basic operations of Helm

- Learn how to create Helm Chart

- Learn how to use Chart Museum as helm repo

## Outline

- Part 1 - Setting up the Kubernetes Cluster

- Part 2 - Installing Helm

- Part 3 - The Chart Repository

## Part 1 - Setting up the Kubernetes Cluster

- Launch a Kubernetes Cluster of Ubuntu 22.04 with two nodes (one master, one worker) using the [Cloudformation Template to Create Kubernetes Cluster](../S2-kubernetes-02-basic-operations/cfn-template-to-create-k8s-cluster.yml). *Note: Once the master node up and running, worker node automatically joins the cluster.*

>*Note: If you have problem with kubernetes cluster, you can use this link for lesson.*
>https://killercoda.com/playgrounds

- Check if Kubernetes is running and nodes are ready.

```bash
kubectl cluster-info
kubectl get no
```

## Part 2 - Installing Helm

* Install Helm [version 3+](https://github.com/helm/helm/releases). [Introduction to Helm](https://helm.sh/docs/intro/). [Helm Installation](https://helm.sh/docs/intro/install/).

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

## Part 3 - The Chart Repository

- In this part, we explain how to create and work with Helm chart repositories. At a high level, a chart repository is a location where packaged charts can be stored and shared. 

- The distributed community Helm chart repository is located at Artifact Hub and welcomes participation. But Helm also makes it possible to create and run your own chart repository. 

- A chart repository is an `HTTP server` that houses an `index.yaml` file and optionally some `packaged charts`. When you're ready to share your charts, the preferred way to do so is by uploading them to a chart repository.

- Because a chart repository can be any HTTP server that can serve YAML and tar files and can answer GET requests, we have a plethora of options when it comes down to hosting your own chart repository. For example, we can use a Google Cloud Storage (GCS) bucket, Amazon S3 bucket, GitHub Pages, or even create your own web server.

### Hosting Chart Repositories

#### ChartMuseum Repository Server

- ChartMuseum is an open-source Helm Chart Repository server written in Go (Golang), with support for cloud storage backends, including Google Cloud Storage, Amazon S3, Microsoft Azure Blob Storage, Alibaba Cloud OSS Storage, Openstack Object Storage, Oracle Cloud Infrastructure Object Storage, Baidu Cloud BOS Storage, Tencent Cloud Object Storage, DigitalOcean Spaces, Minio, and etcd.

- We can also use the ChartMuseum server to host a chart repository from a local file system.

- Install the chartmuseum.

```bash
curl https://raw.githubusercontent.com/helm/chartmuseum/main/scripts/get-chartmuseum | bash
```


- Configure the chartmuseum repo for use with local filesystem storage.

```bash
chartmuseum --debug --port=8080 \
  --storage="local" \
  --storage-local-rootdir="./chartstorage"
```

- Check the repo on your browser. (Don't forget the open port 8080)

```
<public-ip>:8080
```

- Let's add the repository using the following command.

```bash
helm repo add mylocalrepo http://<public-ip>:8080
```

- List the helm repo's.

```bash
helm repo ls
```

- Find the names of the charts in mylocalrepo

```bash
helm search repo mylocalrepo
```

- Let's store charts in your chart repository. Now that we have a chart repository, let's upload a chart and an index file to the repository. Charts in a chart repository must be packaged `helm package chart-name/` and versioned correctly [following SemVer 2 guidelines](https://semver.org/).

```bash
helm package clarus-chart
```

- Once we have a packaged chart ready, create a new directory, and move your packaged chart to that directory.

```bash
mkdir my-charts
mv clarus-chart-0.1.0.tgz my-charts
helm repo index my-charts --url http://<public-ip>:8080
```

- The last command takes the path of the local directory that we just created and the URL of your remote chart repository and composes an `index.yaml` file inside the given directory path.



### The chart repository structure

- A chart repository consists of packaged charts and a special file called index.yaml which contains an index of all of the charts in the repository. Frequently, the charts that index.yaml describes are also hosted on the same server, as are the provenance files.

For example, the layout of the repository https://example.com/charts might look like this:

```
my-charts/
  |
  |- index.yaml
  |
  |- clarus-chart-0.1.0.tgz
```

### The index file

- The index file is a yaml file called `index.yaml`. It contains some metadata about the package, including the contents of a chart's Chart.yaml file. A valid chart repository must have an index file. The index file contains information about each chart in the chart repository. The `helm repo index` command will generate an index file based on a given local directory that contains packaged charts.

This is the index file of my-charts:

```yaml
apiVersion: v1
entries:
  clarus-chart:
  - apiVersion: v2
    appVersion: 1.16.0
    created: "2021-12-07T11:59:09.466396276+03:00"
    description: A Helm chart for Kubernetes
    digest: 712c46edcd85b167881bb644d8de4391eee9acd76aabb75fa2f6e53bedd1c872
    name: clarus-chart
    type: application
    urls:
    - http://<public ip>:8080/clarus-chart-0.1.0.tgz
    version: 0.1.0
generated: "2021-12-07T11:59:09.466104188+03:00"
```

- Now we can upload the chart and the index file to our chart repository using a sync tool or manually.

```bash
cd my-charts
curl --data-binary "@clarus-chart-0.1.0.tgz" http://<public ip>:8080/api/charts
```

- Now we're going to update all the repositories. It's going to connect all the repositories and check is there any new chart.

```bash
helm search repo mylocalrepo
helm repo update
helm search repo mylocalrepo
```

- Let's see how to maintain the chart version. In `clarus-chart/Chart.yaml`, set the `version` value to `0.1.1`and then package the chart.

```bash
helm package clarus-chart
mv clarus-chart-0.1.1.tgz my-charts
helm repo index my-charts --url http://<public-ip>:8080
```

- Upload the new version of the chart and the index file to our chart repository using a sync tool or manually.

```bash
cd my-charts
curl --data-binary "@clarus-chart-0.1.1.tgz" http://<public ip>:8080/api/charts
```

- Let's update all the repositories.

```bash
helm search repo mylocalrepo
helm repo update
helm search repo mylocalrepo
```

- Check all versions of the chart repo with `-l` flag.

```bash
helm search repo mylocalrepo -l
```

- We can also use the [helm-push plugin](https://github.com/chartmuseum/helm-push):

- Install the helm-push plugin. Firstly check the helm plugins.

```
helm plugin ls
helm plugin install https://github.com/chartmuseum/helm-push.git
```

- In clarus-chart/Chart.yaml, set the `version` value to `0.2.0`and push the chart.

```bash
cd
helm cm-push clarus-chart mylocalrepo
```

- Update and search the mylocalrepo.

```bash
helm search repo mylocalrepo
helm repo update
helm search repo mylocalrepo
```

- We can also change the version with the --version flag.

```bash
helm cm-push clarus-chart mylocalrepo --version="1.2.3"
```

- Update and search the mylocalrepo.

```bash
helm search repo mylocalrepo
helm repo update
helm search repo mylocalrepo
```

- Let's install our chart into the Kubernetes cluster.

- Update the `clarus-chart/templates/configmap.yaml` as below.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  myvalue: "clarus-chart configmap example"
  course: {{ .Values.course }}
  topic: {{ .Values.lesson.topic }}
  time: {{ now | date "2006.01.02" | quote }} 
  count: "first"
```

- Push the chart again.

```bash
helm cm-push clarus-chart mylocalrepo --version="1.2.4"
```

- Install the chart.

```bash
helm repo update
helm search repo mylocalrepo
helm install from-local-repo mylocalrepo/clarus-chart
```

- Check the configmap.

```bash
kubectl get cm
kubectl describe cm from-local-repo-config
```

- This time we will update the release.

- Update the `clarus-chart/templates/configmap.yaml` as below.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  myvalue: "clarus-chart configmap example"
  course: {{ .Values.course }}
  topic: {{ .Values.lesson.topic }}
  time: {{ now | date "2006.01.02" | quote }} 
  count: "second"
```

- Push the chart again.

```bash
helm cm-push clarus-chart mylocalrepo --version="1.2.5"
helm repo update
```

- Update the release.

```bash
helm upgrade from-local-repo mylocalrepo/clarus-chart
```

- Check the configmap.

```bash
kubectl get cm
kubectl describe cm from-local-repo-config
```

- We can check the available versions with `helm history` command.

```bash
helm history from-local-repo
```

- We can upgrade the release to any version with "--version" flag.

```bash
helm upgrade from-local-repo mylocalrepo/clarus-chart --version 1.2.4
```

- Check the configmap.

```bash
kubectl get cm
kubectl describe cm from-local-repo-config
```

- We can rollback our release with `helm rollback` command.

```bash
helm history from-local-repo
helm rollback from-local-repo 1
```

- Check the configmap.

```bash
kubectl get cm
kubectl describe cm from-local-repo-config
```

- Uninstall the release.

```bash
helm uninstall from-local-repo
```

- Remove the localrepo.

```bash
helm repo remove mylocalrepo
```