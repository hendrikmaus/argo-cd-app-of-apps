# Cluster Bootstrapping Experiment Using Argo CD, Apps-of-Apps and Sync Waves

An experiment, running locally, to use the [App-of-Apps](https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/) pattern of Argo CD to provision a cluster (the same cluster in this case) while declaring dependencies between the apps using Sync Waves.

## Requirements

- Docker
- `kubectl`
- [`k3d`](https://k3d.io)
- [`just`](https://github.com/casey/just)
- `bash`
- [`direnv`](https://direnv.net)

## Configuration

The configuration is done using [`.env`](./.env) and [`values/argocd.yaml`](./values/argocd.yaml).

## Usage

Run the experiment:

```shell
just run
```

> The `run` recipe is idompotent.

Inspect the cluster.

Cleanup:

```shell
just clean
```

## Known Issues

The health assessement of the `Application` resource was removed from Argo CD and has to be re-enabled using the `ConfigMap`.

See:

- https://github.com/argoproj/argo-cd/issues/5146
- https://github.com/argoproj/argo-cd/pull/6281

This experiment includes the patch.
