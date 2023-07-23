# KServe

KServe comes with one component:

1. [KServe](#KServe)


## KServe

Contains deployment manifests for the KServe controller.

- [kserve-controller](https://github.com/opendatahub-io/kserve)
  - Forked upstream kserve/kserve repository


## KServe Architecture

A complete architecture can be found at https://kserve.github.io/website/0.10/modelserving/control_plane.

KServe Control Plane: Responsible for reconciling the InferenceService custom resources. It creates the Knative serverless deployment for predictor, transformer, explainer to enable autoscaling based on incoming request workload including scaling down to zero when no traffic is received. When raw deployment mode is enabled, control plane creates Kubernetes deployment, service, ingress, HPA.


## Original manifests

> ❗️Note: Unfortunately, `kfctl` used an outdated version of `kustomize` which cannot process some fields in the KServe manifests.  
> Thus, we are pre-building the KServe manifests to the [kserve-built](./kserve-built) folder. The [patches](#patches) then use
> those pre-built KServe manifests to apply our kustomizations.

KServe also uses `kustomize` so we can (indirectly) use [their manifests](https://github.com/opendatahub-io/kserve/tree/master/config).

* `default` is the entrypoint for CRDs, KServe controller and RBAC resources.

The [pre-built KServe manifests](./kserve-built/kserve-built.yaml) are directly referenced in [base/kustomization.yaml](./base/kustomization.yaml).


### Updating the manifests

Run the script in [hack](./hack) to manually update the pre-built manifests from the upstream manifests. [this file](./hack/kustomization.yaml) defines the version that is being used:

```bash
hack/build-kserve-manifests.sh
```
```text
Building KServe manifests
KServe manifests fetched from upstream and assembled into /odh-manifests/kserve/kserve-built/kserve-built.yaml
```


## Patches

There are patches defined in [kserve/base](./base) to update images and tags for the KServe resources.
 

## Installation process

Following are the steps to install Model Mesh as a part of OpenDataHub install:

1. Install the OpenDataHub operator.
2. Make sure you install Service Mesh and Serverless components and configure them appropriately.
See [OCP official instructions](https://docs.openshift.com/serverless/1.29/integrations/serverless-ossm-setup.html) and the 
3. related documentation for [KServe on Openshift](https://github.com/kserve/kserve/blob/master/docs/OPENSHIFT_GUIDE.md#installation-with-service-mesh) from the kserve repo for more.
4. Create a KfDef that includes the KServe components and runtimes.

```
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  name: opendatahub
  namespace: opendatahub
spec:
  applications:
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: odh-common
      name: odh-common
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: kserve
      name: kserve
  repos:
    - name: manifests
      uri: https://api.github.com/repos/opendatahub-io/odh-manifests/tarball/master
  version: master
```

5. You can now create a new project.

6. Make sure that you have a runtime defined in your target namespace (you can use a [template](https://github.com/opendatahub-io/odh-dashboard/blob/main/manifests/modelserving/ovms-ootb.yaml) in ODH).

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: example-runtime
spec:
...
```
More information in the [KServe docs](https://kserve.github.io/website/0.10/modelserving/servingruntimes/).

7. Create an `InferenceService` CR in your target namespace.


## Using KServe in ODH

You can use the `InferenceService` examples from KServe. Make sure to include the additional annotation for OpenShift Service Mesh:

```yaml
metadata:
  annotations:
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
    serving.knative.openshift.io/enablePassthrough: "true"
```

Example:

```yaml
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "sklearn-iris"
  namespace: kserve-demo
  annotations:
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
    serving.knative.openshift.io/enablePassthrough: "true"
spec:
  predictor:
    model:
      runtime: <your-runtime>
      modelFormat:
        name: sklearn
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
```

