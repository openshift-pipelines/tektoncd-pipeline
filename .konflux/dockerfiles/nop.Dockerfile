ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG MID_RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:34880b64c07f28f64d95737f82f891516de9a3b43583f39970f7bf8e4cfa48b7
ARG RUNTIME=scratch

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -tags strictfipsruntime -v -o /tmp/nop \
    ./cmd/nop

FROM $MID_RUNTIME AS tmp

FROM $RUNTIME
ARG VERSION=pipeline-1.18

COPY --from=tmp /usr/lib64/libcrypto.so.* /usr/lib64/

ENV NOP=/usr/local/bin/nop \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/nop /ko-app/nop
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-nop-rhel9-container" \
      name="openshift-pipelines/pipelines-nop-rhel9" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Nop" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Nop" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Nop" \
      io.k8s.description="Red Hat OpenShift Pipelines Nop" \
      io.openshift.tags="pipelines,tekton,openshift" \
      vendor="Red Hat, Inc." \
      distribution-scope="public" \
      url="https://access.redhat.com/containers/#/registry.access.redhat.com/ubi9-minimal/images/9.4-1227.1725849298" \
      release="1227.1725849298" \
      cpe="cpe:/a:redhat:openshift_pipelines:1.18::el9"

USER 65532

ENTRYPOINT ["/ko-app/nop"]
