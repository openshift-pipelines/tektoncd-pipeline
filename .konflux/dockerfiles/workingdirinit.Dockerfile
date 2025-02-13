ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:db8bf20cac0f250659f1ffbba929639dcd7e09863c20c99c5cb8f3ce8ded0497

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/workingdirinit \
    ./cmd/workingdirinit

FROM $RUNTIME
ARG VERSION=pipeline-main

ENV WORKINGDIRINIT=/usr/local/bin/workingdirinit \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/workingdirinit /ko-app/workingdirinit
COPY head ${KO_DATA_PATH}/HEAD

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

RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/workingdirinit"]
