ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=scratch

FROM $GO_BUILDER AS builder

ARG PIPELINE_UPSTREAM_COMMIT

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV CHANGESET_REV=$CI_PIPELINE_UPSTREAM_COMMIT
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=${CHANGESET_REV:0:7}'" -mod=vendor -tags disable_gcp -v -o /tmp/nop \
    ./cmd/nop
RUN /bin/sh -c 'echo ${CHANGESET_REV} > /tmp/HEAD'

FROM $RUNTIME
ARG VERSION=pipeline-main

ENV NOP=/usr/local/bin/nop \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/nop /ko-app/nop
COPY --from=builder /tmp/HEAD ${KO_DATA_PATH}/HEAD

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
