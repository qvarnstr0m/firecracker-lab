# A small Go HTTP service.
#   docker build -t fc-go-hello rootfs/images/go-hello
#   make rootfs IMAGE=fc-go-hello ROOTFS=go-hello
#
# The runtime stage is Alpine rather than scratch because fc-init needs /bin/sh.
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 go build -o /hello main.go

FROM alpine:3.22
COPY --from=build /hello /usr/local/bin/hello
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/hello"]
