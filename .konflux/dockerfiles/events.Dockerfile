ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:1.25
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:83006d535923fcf1345067873524a3980316f51794f01d8655be55d6e9387183

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
ARG VERSION=next

ENV EVENTS=/usr/local/bin/events \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/events /ko-app/events
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-events-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:next::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,events" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-events-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline events" \
    version="next"

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/events"]

