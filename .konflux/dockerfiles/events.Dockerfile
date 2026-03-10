ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:9.7-1773088126
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:6fc28bcb6776e387d7a35a2056d9d2b985dc4e26031e98a2bd35a7137cd6fd71 

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/events \
    ./cmd/events

FROM $RUNTIME
ARG VERSION=1.21

ENV EVENTS=/usr/local/bin/events \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/events /ko-app/events
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-events-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.21::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,events" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-events-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    version="v1.21.1"

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/events"]

