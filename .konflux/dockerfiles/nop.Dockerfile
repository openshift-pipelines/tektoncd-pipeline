ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=scratch

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/nop \
    ./cmd/nop

FROM $RUNTIME
ARG VERSION=pipeline-main

ENV NOP=/usr/local/bin/nop \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/nop /ko-app/nop
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-nop-rhel8-container" \
      name="openshift-pipelines/pipelines-nop-rhel8" \
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
      release="1227.1725849298"

USER 65532

ENTRYPOINT ["/ko-app/nop"]
