# Hands-on Kubernetes-08: Helm Basics

The purpose of this hands-on training is to give students an understanding of the basic operations of Helm.

## Learning Outcomes

At the end of this hands-on training, students will be able to;

- Learn basic operations of Helm

- Learn how to create a Helm Chart

- Learn how to use GitHub as a Helm repo

## Outline

- Part 1 - Setting up the Kubernetes Cluster

- Part 2 - Basic Operations with Helm

- Part 3 - Creating Helm chart

- Part 4 - The Chart Repository (Set up a Helm v3 chart repository in GitHub)

## Part 1 - Setting up the Kubernetes Cluster

- Launch a Kubernetes Cluster of Ubuntu 22.04 with two nodes (one master, one worker) using the [Cloudformation Template to Create Kubernetes Cluster](../S2-kubernetes-02-basic-operations/cfn-template-to-create-k8s-cluster.yml). *Note: Once the master node is up and running, the worker node automatically joins the cluster.*

>*Note: If you have a problem with kubernetes cluster, you can use this link for the lesson.*
>https://killercoda.com/playgrounds

- Check if Kubernetes is running and nodes are ready.

```bash
kubectl cluster-info
kubectl get no
```

## Part 2 - Basic Operations with Helm

### [Three Big Concepts](https://helm.sh/docs/intro/using_helm/)

- A `Chart` is a Helm package. It contains all of the resource definitions necessary to run an application, tool, or service inside of a Kubernetes cluster. Think of it like the Kubernetes equivalent of a Homebrew formula, an Apt dpkg, or a Yum RPM file.

- A `Repository` is the place where charts can be collected and shared. It's like Perl's CPAN archive or the Fedora Package Database, but for Kubernetes packages.

- A `Release` is an instance of a chart running in a Kubernetes cluster. One chart can often be installed many times in the same cluster. And each time it is installed, a new release is created. Consider a PostgreSQL chart. If we want two databases running in your cluster, we can install that chart twice. Each one will have its own release, which will in turn have its own release name.

- With these concepts in mind, we can now explain Helm like this:

**Helm installs charts into Kubernetes, creating a new release for each installation. And to find new charts, we can search Helm chart repositories.**

* Install Helm [version 4+](https://github.com/helm/helm/releases). [Introduction to Helm](https://helm.sh/docs/intro/). [Helm Installation](https://helm.sh/docs/intro/install/).

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### helm search: Finding Charts

- Helm comes with a powerful search command. It can be used to search two different types of sources:

- `helm search hub` searches the Artifact Hub, which lists Helm charts from dozens of different repositories.

- `helm search repo` searches the repositories that we have added to your local Helm client (with helm repo add). This search is done over local data, and no public network connection is needed.

- We can find publicly available charts by running helm search hub:

```bash
helm search hub
```

- Searches for all WordPress charts on Artifact Hub.

```bash
helm search hub wordpress
```

- We can add the repository using the following command.

```bash
helm repo ls
helm repo add bitnami https://charts.bitnami.com/bitnami
# helm repo remove bitnami
```

- Using helm search repo, we can find the names of the charts in repositories we have already added:

```bash
helm search repo bitnami
```

- Type the `helm install command` to install a chart.

```bash
helm repo update
helm repo ls
helm ls
helm install my-release bitnami/postgresql
helm ls
```

- We get a simple idea of the features of this PostgreSQL chart by running `helm show chart bitnami/postgresql`. Or we could run `helm show all bitnami/postgresql` to get all information about the chart.

```bash
helm show chart bitnami/postgresql
helm show all bitnami/postgresql
```

- Installing the way we have here will only use the default configuration options for this chart. Many times, you will want to customize the chart to use your preferred configuration. To see what options are configurable on a chart, use helm show values.


```bash
helm show values bitnami/postgresql
```

- Whenever we install a chart, a new release is created. So one chart can be installed multiple times into the same cluster. And each can be independently managed and upgraded.

- Install a new release with the bitnami/wordpress chart.

```bash
helm install my-release \
  --set wordpressUsername=admin \
  --set wordpressPassword=password \
  --set mariadb.auth.rootPassword=secretpassword \
    bitnami/wordpress
```

- It's easy to see what has been released using Helm.

```bash
helm list
```

- Uninstall a release.

```bash
helm uninstall my-release
helm uninstall my-release
```

## Part 3 - Creating Helm chart

- Create a new chart with the following command.

```bash
helm create my-chart
```

- See the files of my-chart.

```bash
ls my-chart
```

- Remove the files from the `templates` folder.

```bash
rm -rf my-chart/templates/*
```

- Create a `configmap.yaml` file under the `my-chart/templates` folder with the following content.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-chart-config
data:
  myvalue: "my-chart configmap example"
  course: "DevOps"
```

- Install the my-chart.

```bash
helm install helm-demo my-chart
```

- The output is similar to:

```bash
NAME: helm-demo
LAST DEPLOYED: Mon Dec  6 11:39:46 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

- List the releases.

```bash
helm ls
```

- Let's see the configmap.

```bash
kubectl get cm
kubectl describe cm my-chart-config
```

- Remove the release.

```bash
helm uninstall helm-demo
```

- Let's create our own values and use them     within the template. Update the `my-chart/values.yaml` as below.

```yaml
course: DevOps
```

- Edit the my-chart/templates/configmap.yaml as below.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-chart-config
data:
  myvalue: "my-chart configmap example"
  course: {{ .Values.course }}
``` 

- Let's see how the values are getting substituted with the `dry-run` option.

```bash
helm install --debug --dry-run mydryrun my-chart
```

- Install the my-chart.

```bash
helm install myvalue my-chart
```

- Check the values that got deployed with the following command.

```bash
helm get manifest myvalue
```

- Remove the release.

```bash
helm uninstall myvalue
```

- Let's change the default value from the values.yaml file when the release is getting released.

```bash
helm install --debug --dry-run setflag my-chart --set course=AWS
```

### Predefined Values

- Values that are supplied via a values.yaml file (or via the --set flag) is accessible from the .Values object in a template. But there are other pre-defined pieces of data you can access in your templates. For example:

  - Release.Name: The name of the release (not the chart)
  - Release.Namespace: The namespace the chart was released to.

- These values are pre-defined, are available to every template, and cannot be overridden. As with all values, the names are case sensitive.

- Helm has over 60 available functions. Some of them are defined by the [Go template language](https://pkg.go.dev/text/template) itself. Most of the others are part of the [Sprig template](https://masterminds.github.io/sprig/) library. Let's see some functions.

- Let's try more examples to get more clarity. Update the `my-chart/values.yaml` as below.

```yaml
course: DevOps
lesson:
  topic: helm
```

- Update the `my-chart/templates/configmap.yaml` as below.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  myvalue: "my-chart configmap example"
  course: {{ quote .Values.course }}
  topic: {{ upper .Values.lesson.topic }}
  time: {{ now | date "2006.01.02" | quote }} 
```

- Let's see how the values are getting substituted with the `dry-run` option.

```bash
helm install --debug --dry-run builtin-object my-chart
```
- **now** function shows the current date/time.

- **date** function formats a date.

### Helm Notes:

- In this part, we are going to look at Helm's tool for providing instructions to your chart users. At the end of a `helm install` or `helm upgrade`, Helm can print out a block of helpful information for users. This information is highly customizable using templates.

- To add installation notes to your chart, simply create a `my-chart/NOTES.txt` file. This file is plain text, but it is processed like a template and has all the normal template functions and objects available.

- Let's create a simple `NOTES.txt` file under `my-chart/templates` folder.

```txt
Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To learn more about the release, try:

  $ helm status {{ .Release.Name }}
  $ helm get all {{ .Release.Name }}
```

- Let's run our Helm chart.

```bash
helm install notes-demo my-chart
```

- Using NOTES.txt this way is a great way to give your users detailed information about how to use their newly installed chart. Creating a NOTES.txt file is strongly recommended, though it is not required.

- Let's see how to maintain the chart version. 

- First, update the `my-chart/values.yaml` as below.

```yaml
course: AWS
lesson:
  topic: helm
```

- Next, in `my-chart/Chart.yaml`, set the `version` value to `0.1.1`and then package the chart.

```bash
helm upgrade notes-demo my-chart
```

- We can check the available versions with `helm history` command.

```bash
helm ls
helm history notes-demo
```

- We can rollback our release with `helm rollback` command.

```bash
kubectl get cm
kubectl describe cm notes-demo-config
helm rollback notes-demo 1
helm ls
```

- Check the configmap.

```bash
helm history notes-demo
kubectl describe cm notes-demo-config
```

- Remove the release.

```bash
helm uninstall notes-demo
helm ls
kubectl get cm
```

## Part 4 - The Chart Repository

- In this part, we explain how to create and work with Helm chart repositories. At a high level, a chart repository is a location where packaged charts can be stored and shared. 

- The distributed community Helm chart repository is located at Artifact Hub and welcomes participation. But Helm also makes it possible to create and run your own chart repository. 

- A chart repository is an `HTTP server` that houses an `index.yaml` file and optionally some `packaged charts`. When you're ready to share your charts, the preferred way to do so is by uploading them to a chart repository.

- Because a chart repository can be any HTTP server that can serve YAML and tar files and can answer GET requests, we have a plethora of options when it comes to hosting your own chart repository. For example, we can use a Google Cloud Storage (GCS) bucket, an Amazon S3 bucket, GitHub Pages, or even create our own web server.

## Part 4 - Set up a Helm v3 chart repository in Github (Optional)

- Create a GitHub repo and name it `mygithubrepo`.

- Produce GitHub Apps Personal access tokens. Go to <your avatar> --> Settings --> Developer settings and click Personal access tokens. Make sure to copy your personal access token now. You won’t be able to see it again!

- Create a GitHub repository locally and push it.

```bash
mkdir mygithubrepo
cd mygithubrepo
echo "# mygithubrepo" >> README.md
git init
git add README.md
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/<your github name>/mygithubrepo.git
git push -u origin main
```

- Let's store charts in your chart repository. Now that we have a chart repository, let's upload a chart and an index file to the repository. Charts in a chart repository must be packaged `helm package chart-name/` and versioned correctly [following SemVer 2 guidelines](https://semver.org/).

- Package the repo under the `mygithubrepo` folder.

```bash
cd mygithubrepo
helm package ../my-chart
```

### The chart repository structure

- A chart repository consists of packaged charts and a special file called index.yaml, which contains an index of all of the charts in the repository. Frequently, the charts that index.yaml describes are also hosted on the same server, as are the provenance files.

For example, the layout of the repository https://example.com/charts might look like this:

```
my-charts/
  |
  |- index.yaml
  |
  |- my-chart-0.1.0.tgz
```

### The index file

- The index file is a yaml file called `index.yaml`. It contains some metadata about the package, including the contents of a chart's Chart.yaml file. A valid chart repository must have an index file. The index file contains information about each chart in the chart repository. The `helm repo index` command will generate an index file based on a given local directory that contains packaged charts.

- Generate an index file in the current directory.

```bash
helm repo index .
```

- Commit and push the repo.

```bash
git add .
git commit -m "my-chart is added"
git push
```

- Add this repo to your repos. Go to <your repo> --> README.md and click Raw. Copy to address without README.md like below. This will be repo url.

```
https://raw.githubusercontent.com/<github-user-name>/mygithubrepo/main
```

- List the repos and add mygithubrepo.

```bash
helm repo list
helm repo add --username <github-user-name> --password <personel-access-token> my-github-repo 'https://raw.githubusercontent.com/<github-user-name>/mygithubrepo/main'
helm repo list
```

- Let's search the repo.

```bash
helm search repo my-github-repo
```

- Add new charts to the repo.

```bash
cd ..
helm create second-chart
cd mygithubrepo
helm package ../second-chart
helm repo index .
git add .
git commit -m "second chart is added"
git push
```

- Update and search the repo.

```bash
helm repo update
helm search repo my-github-repo
```

- Create a release from my-github-repo

```bash
helm install github-repo-release my-github-repo/second-chart
helm ls
```

- Check the objects.

```bash
kubectl get deployment
kubectl get svc
```

- Uninstall the release.

```bash
helm uninstall github-repo-release
```

- Remove the localrepo.

```bash
helm repo remove my-github-repo
helm repo ls
```
