_default:
  just --list --unsorted

# The cluster name used within k3d
cluster := "cluster-setup-experiment"

# runs the complete experiment; call 'clean' afterwards for teardown
run:
  #!/usr/bin/env bash
  set -euo pipefail
  just _pull-images
  just _create-cluster 
  just _apply-argo-cd
  just _wait-for-argo-cd
  echo ""
  echo "Argo CD has been deployed, the next step will submit the app-of-apps"
  echo "  open it in the browser as printed above to follow the progress."
  echo ""
  echo "Here is what you'll observe:"
  echo " 1) an app called 'some-cluster' will appear"
  echo " 2) next, the 'istio-operator' app will appear"
  echo " 3) once the second app is synced, 'istio-profile' will appear"
  echo ""
  echo "You can repeat this process forward and backward using"
  echo "  'just delete-apps' / 'just apply-apps'"
  echo ""
  echo "Press any key to continue or abort with ctrl+c"
  # shellcheck disable=SC2162
  read
  just apply-apps
  echo ""
  echo "You can cleanup using 'just clean' when you're done"

# pulls images to the host; later they are imported into the k3d cluster
_pull-images:
  #!/usr/bin/env bash
  set -euo pipefail
  ( docker pull "quay.io/argoproj/argocd:${ARGO_CD_VERSION}" ) &
  ( docker pull "redis:${ARGO_CD_REDIS_VERSION}" ) &
  # shellcheck disable=SC2046
  wait $(jobs -p)

# create the k3d cluster, if it doesn't exist and import cached container images
_create-cluster:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! k3d cluster list | grep -qF "cluster-setup-experiment"; then
    echo "Creating Kubernetes cluster ..."
    k3d cluster create {{cluster}} --config ./k3d-default.yaml
    # note: image imports CANNOT run in parallel
    k3d image import "quay.io/argoproj/argocd:${ARGO_CD_VERSION}" --cluster {{cluster}}
    k3d image import "redis:${ARGO_CD_REDIS_VERSION}" --cluster {{cluster}}
  else
    echo "Cluster already exists ... skip"
  fi

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
    --values ./argo-cd.yaml \
    --set global.image.tag="${ARGO_CD_VERSION}" \
    --set redis.image.tag="${ARGO_CD_REDIS_VERSION}" \
    --repo https://argoproj.github.io/argo-helm \
    --version "${ARGO_CD_CHART_VERSION}" \
    | kubectl --namespace argocd apply --filename -

# wait for Argo CD to be rolled out
_wait-for-argo-cd:
  #!/usr/bin/env bash
  set -euo pipefail

  ( kubectl --namespace argocd rollout status deployment argocd-application-controller --watch=true ) &
  ( kubectl --namespace argocd rollout status deployment argocd-repo-server --watch=true ) &
  ( kubectl --namespace argocd rollout status deployment argocd-server --watch=true ) &
  ( kubectl --namespace argocd rollout status deployment argocd-redis --watch=true ) &
  
  # shellcheck disable=SC2046
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
  rm "${KUBECONFIG}"

