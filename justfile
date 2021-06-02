_default:
  just --list --unsorted

cluster := "cluster-setup-experiment"

# runs the complete experiment; call 'clean' afterwards for teardown
run:
  just _pull-images
  just _create-cluster 
  just _apply-argo-cd
  just _wait-for-argo-cd
  just apply-apps

# pulls images to the host; later they are imported into the k3d cluster
_pull-images:
  #!/usr/bin/env bash
  set -euo pipefail
  ( docker pull quay.io/argoproj/argocd:${ARGO_CD_VERSION} ) &
  ( docker pull redis:${ARGO_CD_REDIS_VERSION} ) &
  wait $(jobs -p)

# create the k3d cluster, if it doesn't exist and import cached container images
_create-cluster:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! k3d cluster list | grep -qF "cluster-setup-experiment"; then
    echo "Creating Kubernetes cluster ..."
    k3d cluster create {{cluster}} --config ./k3d-default.yaml
    # note: image imports CANNOT run in parallel
    k3d image import quay.io/argoproj/argocd:${ARGO_CD_VERSION} --cluster {{cluster}}
    k3d image import redis:${ARGO_CD_REDIS_VERSION} --cluster {{cluster}}
  else
    echo "Cluster already exists ... skip"
  fi

  echo ""
  echo "The cluster is ready to be observed (e.g. 'k9s -n all')"

# apply the Argo CD chart to the cluster
_apply-argo-cd:
  #!/usr/bin/env bash
  set -euo pipefail

  if [[ "$(kubectl get namespace argocd --ignore-not-found)" == "" ]]; then
    kubectl create namespace argocd
  fi

  helm template argocd argo-cd \
    --namespace argocd \
    --include-crds \
    --values ./values/argocd.yaml \
    --set global.image.tag=${ARGO_CD_VERSION} \
    --set redis.image.tag=${ARGO_CD_REDIS_VERSION} \
    --repo https://argoproj.github.io/argo-helm \
    --version ${ARGO_CD_CHART_VERSION} \
    | kubectl --namespace argocd apply --filename -

# wait for Argo CD to be rolled out
_wait-for-argo-cd:
  #!/usr/bin/env bash
  set -euo pipefail

  ( kubectl --namespace argocd rollout status deployment argocd-application-controller --watch=true ) &
  ( kubectl --namespace argocd rollout status deployment argocd-repo-server --watch=true ) &
  ( kubectl --namespace argocd rollout status deployment argocd-server --watch=true ) &
  ( kubectl --namespace argocd rollout status deployment argocd-redis --watch=true ) &
  
  wait $(jobs -p)

  echo ""
  echo "Open http://localhost:8085"
  echo "Login: admin admin"  

# apply the app-of-apps
apply-apps:
  kubectl --namespace argocd apply --filename app-of-apps.yaml

# remove the app-of-apps
delete-apps:
  kubectl --namespace argocd delete --filename app-of-apps.yaml

# teardown the experiment
clean:
  k3d cluster delete {{cluster}}
  rm ${KUBECONFIG}

