ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.23
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:30bbd445046a3a63f5f5557a3c67dee74e3c8e7855eb0347630b020f3689823f

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp -v -o /tmp/events \
    ./cmd/events

FROM $RUNTIME
ARG VERSION=pipeline-next

ENV EVENTS=/usr/local/bin/events \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/events /ko-app/events
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
      com.redhat.component="openshift-pipelines-events-rhel9-container" \
      name="openshift-pipelines/pipelines-events-rhel9" \
      version=$VERSION \
      summary="Red Hat OpenShift Pipelines Events" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Events" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Events" \
      io.k8s.description="Red Hat OpenShift Pipelines Events" \
      io.openshift.tags="pipelines,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/events"]

