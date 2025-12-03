ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:161a4e29ea482bab6048c2b36031b4f302ae81e4ff18b83e61785f40dc576f5d

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
ARG VERSION=pipeline-1.19.4

ENV SIDECARLOGRESULTS=/usr/local/bin/sidecarlogresults \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/sidecarlogresults /ko-app/sidecarlogresults
COPY head ${KO_DATA_PATH}/HEAD 

LABEL \
      com.redhat.component="openshift-pipelines-sidecarlogresults-rhel9-container" \
      name="openshift-pipelines/pipelines-sidecarlogresults-rhel9" \
      version=$VERSION \
      cpe="cpe:/a:redhat:openshift_pipelines:1.19::el9" \
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
