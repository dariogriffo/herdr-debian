ARG DEBIAN_DIST=bookworm
FROM debian:bookworm

ARG DEBIAN_DIST
ARG herdr_VERSION
ARG BUILD_VERSION
ARG FULL_VERSION
ARG ARCH
ARG HERDR_ASSET

RUN mkdir -p /output/usr/bin
RUN mkdir -p /output/usr/share/doc/herdr
RUN mkdir -p /output/DEBIAN

COPY ${HERDR_ASSET}/* /output/usr/bin/
COPY output/DEBIAN/control /output/DEBIAN/
COPY output/DEBIAN/postinst /output/DEBIAN/postinst
RUN chmod 755 /output/DEBIAN/postinst
RUN chmod 755 /output/usr/bin/herdr
COPY output/copyright /output/usr/share/doc/herdr/
COPY output/changelog.Debian /output/usr/share/doc/herdr/
COPY output/README.md /output/usr/share/doc/herdr/

RUN sed -i "s/DIST/$DEBIAN_DIST/" /output/usr/share/doc/herdr/changelog.Debian
RUN sed -i "s/FULL_VERSION/$FULL_VERSION/" /output/usr/share/doc/herdr/changelog.Debian
RUN sed -i "s/DIST/$DEBIAN_DIST/" /output/DEBIAN/control
RUN sed -i "s/herdr_VERSION/$herdr_VERSION/" /output/DEBIAN/control
RUN sed -i "s/BUILD_VERSION/$BUILD_VERSION/" /output/DEBIAN/control
RUN sed -i "s/SUPPORTED_ARCHITECTURES/$ARCH/" /output/DEBIAN/control

RUN dpkg-deb --build /output /herdr_${FULL_VERSION}.deb
