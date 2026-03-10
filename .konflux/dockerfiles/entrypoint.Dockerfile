ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:9.7-1773088126
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:c7d44146f826037f6873d99da479299b889473492d3c1ab8af86f08af04ec8a0

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN CGO_ENABLED=0 \
    go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,disable_spire,disable_tls,strictfipsruntime -v -o /tmp/entrypoint \
    ./cmd/entrypoint

FROM $RUNTIME
ARG VERSION=next

ENV ENTRYPOINT=/usr/local/bin/entrypoint \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/entrypoint /ko-app/entrypoint
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-entrypoint-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:next::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,entrypoint" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-entrypoint-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    version="next"

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/entrypoint"]
