ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=registry.redhat.io/ubi8/ubi:latest@sha256:a444712276a635c9312d83a4ff7c6ee7f2ce08eeb5bd9ca291b5fdba257a5e63

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
ARG VERSION=pipeline-1.14.6

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
      io.openshift.tags="pipelines,tekton,openshift" \
      cpe="cpe:/a:redhat:openshift_pipelines:1.14::el8"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/sidecarlogresults"]
