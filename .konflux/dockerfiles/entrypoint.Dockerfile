ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:latest@sha256:23c7cb17e9c53a65f9ab01f2edf1a4e07c9a9dc2258ed63d69e06925e7cea381
ARG UBI_RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:08d4c70f1baf6537a0728656cf7942d561e74a35916509d205b6519861266352

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

FROM $UBI_RUNTIME
ARG VERSION=1.23

ENV ENTRYPOINT=/usr/local/bin/entrypoint \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/entrypoint /ko-app/entrypoint
COPY head ${KO_DATA_PATH}/HEAD

LABEL \
    com.redhat.component="openshift-pipelines-entrypoint-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.23::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,entrypoint" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-entrypoint-rhel9" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline entrypoint" \
    version="v1.23.5"

RUN groupadd -r -g 65532 nonroot && \
    useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/ko-app/entrypoint"]
