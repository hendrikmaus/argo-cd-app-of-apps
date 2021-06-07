# Cluster Bootstrapping Experiment Using Argo CD, App-of-Apps and Sync Waves

An experiment, running locally, to use the [App-of-Apps](https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/) pattern of Argo CD to provision a cluster (the same cluster in this case) while declaring dependencies between the apps using Sync Waves.

## Requirements

- Docker
- `kubectl`
- [`k3d`](https://k3d.io)
- [`just`](https://github.com/casey/just)
- `bash`
- [`direnv`](https://direnv.net)

## Configuration

The configuration is done using [`.env`](./.env) and [`argo-cd.yaml`](argo-cd.yaml).

## Usage

Run the experiment:

```shell
just run
```

> The `run` recipe is idempotent.

Inspect the cluster.

Cleanup:

```shell
just clean
```

## Structure

```txt
.
├── app-of-apps.yaml                <-- defines a cluster; one would have one of these per cluster
├── apps                            <-- this chart contains the apps of a cluster including dependencies
│  ├── Chart.yaml                         i.e. sync waves, hooks etc. (app-of-apps.yaml points to this chart)
│  ├── templates
│  │  ├── istio-operator.yaml
│  │  └── istio-profile.yaml
│  └── values.yaml
├── argo-cd.yaml                    <-- values file for the argo-cd demo deployment
├── charts                          <-- this directory simulates a chart musuem to be used 
│  └── istio-profile                      by the Argo CD `Application` resources in the `apps` chart above
│     ├── Chart.yaml
│     ├── templates
│     │  ├── namespace.yaml
│     │  └── profile.yaml
│     └── values.yaml
├── justfile
├── k3d-default.yaml
├── kubeconfig
└── README.md
```

## Known Issues

The health assessment of the `Application` resource was removed from Argo CD and has to be re-enabled using the `ConfigMap`.

See:

- https://github.com/argoproj/argo-cd/issues/5146
- https://github.com/argoproj/argo-cd/pull/6281

This experiment includes the patch.
