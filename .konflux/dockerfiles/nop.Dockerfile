ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:latest@sha256:cab9089469c52029e4d8a4e9f717e87c51ab22eed448ebcada101b811f97dfe7
ARG UBI_RUNTIME=registry.redhat.io/ubi9/ubi-minimal-pqc:latest@sha256:72187ec58a94bd958ff48e41881d7c5d8bc0b49586cc1661da5ba4d92374c206
# Add FIPS compliance layer
ARG FIPS_BUILDER=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:bba2b4bbf0ed15cfe7dd72a1e17ae7d2015a141f306b304e1a2785c41400e39c
FROM $FIPS_BUILDER AS fips_builder

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/pipeline
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD
ENV GOEXPERIMENT=strictfipsruntime
ENV GODEBUG="http2server=0"
RUN go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/nop \
    ./cmd/nop

FROM $UBI_RUNTIME
ARG VERSION=1.24

ENV NOP=/usr/local/bin/nop \
    KO_APP=/ko-app \
    KO_DATA_PATH=/kodata

COPY --from=builder /tmp/nop /ko-app/nop
COPY head ${KO_DATA_PATH}/HEAD

# Copy FIPS-compliant libraries
COPY --from=fips_builder /usr/lib64/libcrypto.so.3 /usr/lib64/
COPY --from=fips_builder /usr/lib64/libcrypto.so.3* /usr/lib64/
COPY --from=fips_builder /usr/lib64/ossl-modules/fips.so /usr/lib64/ossl-modules/
COPY --from=fips_builder /etc/redhat-release /etc/

LABEL \
    com.redhat.component="openshift-pipelines-nop-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.24::el9" \
    description="Red Hat OpenShift Pipelines tektoncd-pipeline nop" \
    distribution-scope="public" \
    io.k8s.description="Red Hat OpenShift Pipelines tektoncd-pipeline nop" \
    io.k8s.display-name="Red Hat OpenShift Pipelines tektoncd-pipeline nop" \
    io.openshift.tags="tekton,openshift,tektoncd-pipeline,nop" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-nop-rhel9" \
    release="1227.1725849298" \
    summary="Red Hat OpenShift Pipelines tektoncd-pipeline nop" \
    url="https://access.redhat.com/containers/#/registry.access.redhat.com/ubi9-minimal/images/9.4-1227.1725849298" \
    vendor="Red Hat, Inc." \
    version="v1.24.3"

USER 65532

ENTRYPOINT ["/ko-app/nop"]
