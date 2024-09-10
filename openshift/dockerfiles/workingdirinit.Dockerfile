ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:1b6d711648229a1c987f39cfdfccaebe2bd92d0b5d8caa5dbaa5234a9278a0b2

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY pipeline.HEAD HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/workingdirinit \
    ./cmd/workingdirinit

FROM $RUNTIME
ARG VERSION=pipeline-main

ENV WORKINGDIRINIT=/usr/local/bin/workingdirinit \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/workingdirinit /ko-app/workingdirinit
COPY pipeline.HEAD ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-workingdirinit-rhel8-container" \
      name="openshift-pipelines/pipelines-workingdirinit-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Workingdirinit" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Workingdirinit" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Workingdirinit" \
      io.k8s.description="Red Hat OpenShift Pipelines Workingdirinit" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN microdnf install -y shadow-utils
RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/workingdirinit"]
