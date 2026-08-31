# Static toybox with OpenSSL-backed HTTPS wget, layered into a scratch image.
# No buildkit-only features: also builds with the legacy builder (e.g. colima).
FROM alpine:3.22 AS build

RUN apk add --no-cache build-base bash linux-headers openssl-dev openssl-libs-static ca-certificates

WORKDIR /src
COPY . .

RUN make defconfig \
 && sed -i -e 's/# CONFIG_TOYBOX_LIBCRYPTO is not set/CONFIG_TOYBOX_LIBCRYPTO=y/' \
           -e 's/# CONFIG_SH is not set/CONFIG_SH=y/' .config \
 && grep -q '^CONFIG_TOYBOX_LIBCRYPTO=y' .config \
 && grep -q '^CONFIG_SH=y' .config \
 && make -j"$(nproc)" CFLAGS="-U_FORTIFY_SOURCE" LDFLAGS="--static" \
 && ./toybox --version \
 && mkdir -p /rootfs/bin /rootfs/etc/ssl/certs \
 && cp toybox /rootfs/bin/toybox \
 && ln -s toybox /rootfs/bin/sh \
 && cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/ca-certificates.crt \
 && cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/cert.pem

FROM scratch
COPY --from=build /rootfs/ /
ENTRYPOINT ["/bin/toybox"]
CMD ["sh"]
