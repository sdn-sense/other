FROM haproxy:2.9

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        dnsutils \
        wget \
        alien \
        dpdk \
        ca-certificates \
        netcat-traditional \
        traceroute \
        curl \
        fetch-crl \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://repo.opensciencegrid.org/osg/25-main/el9/release/x86_64/Packages/o/osg-ca-certs-1.138-1.osg25.el9.noarch.rpm && \
    alien -d osg-ca-certs-1.138-1.osg25.el9.noarch.rpm && \
    dpkg -i osg-ca-certs_1.138-2_all.deb; \
    rm -f osg-ca-certs_1.138-2_all.deb osg-ca-certs-1.138-1.osg25.el9.noarch.rpm;

# Refresh CRLs (never fail build)
RUN fetch-crl || true

USER haproxy