# A tiny static web server: BusyBox httpd on Alpine.
#   docker build -t fc-static-web rootfs/images/static-web
#   make rootfs IMAGE=fc-static-web ROOTFS=static-web
FROM alpine:3.22
COPY index.html /www/index.html
EXPOSE 80
CMD ["httpd", "-f", "-v", "-p", "80", "-h", "/www"]
