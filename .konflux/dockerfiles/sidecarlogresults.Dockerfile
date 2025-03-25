ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.21
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:8bd1b6306f8164de7fb0974031a0f903bd3ab3e6bcab835854d3d9a1a74ea5db

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/sidecarlogresults \
    ./cmd/sidecarlogresults

FROM $RUNTIME
ARG VERSION=pipeline-1-14

ENV SIDECARLOGRESULTS=/usr/local/bin/sidecarlogresults \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/sidecarlogresults /ko-app/sidecarlogresults
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-sidecarlogresults-rhel8-container" \
      name="openshift-pipelines/pipelines-sidecarlogresults-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Sidecarlogresults" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Sidecarlogresults" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Sidecarlogresults" \
      io.k8s.description="Red Hat OpenShift Pipelines Sidecarlogresults" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/sidecarlogresults"]
