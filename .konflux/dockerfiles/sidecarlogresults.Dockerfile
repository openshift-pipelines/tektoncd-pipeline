ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:7c5495d5fad59aaee12abc3cbbd2b283818ee1e814b00dbc7f25bf2d14fa4f0c

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/sidecarlogresults \
    ./cmd/sidecarlogresults

FROM $RUNTIME
ARG VERSION=pipeline-next

ENV SIDECARLOGRESULTS=/usr/local/bin/sidecarlogresults \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/sidecarlogresults /ko-app/sidecarlogresults
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-sidecarlogresults-rhel9-container" \
      name="openshift-pipelines/pipelines-sidecarlogresults-rhel9" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Sidecarlogresults" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Sidecarlogresults" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Sidecarlogresults" \
      io.k8s.description="Red Hat OpenShift Pipelines Sidecarlogresults" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/sidecarlogresults"]
