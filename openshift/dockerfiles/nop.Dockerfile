ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=scratch

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY pipeline.HEAD HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/nop \
    ./cmd/nop

FROM $RUNTIME
ARG VERSION=pipeline-main

ENV NOP=/usr/local/bin/nop \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/nop /ko-app/nop
COPY pipeline.HEAD ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-nop-rhel8-container" \
      name="openshift-pipelines/pipelines-nop-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Nop" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Nop" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Nop"

USER 65532

ENTRYPOINT ["/ko-app/nop"]
