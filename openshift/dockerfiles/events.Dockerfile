ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.22
ARG RUNTIME=registry.redhat.io/ubi8/ubi-minimal:latest

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY pipeline.HEAD HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/events \
    ./cmd/events

FROM $RUNTIME
ARG VERSION=pipeline-main

ENV EVENTS=/usr/local/bin/events \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/events /ko-app/events
COPY pipeline.HEAD ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-events-rhel8-container" \
      name="openshift-pipelines/pipelines-events-rhel8" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Events" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Events" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Events"

RUN microdnf install -y shadow-utils
RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/events"]

