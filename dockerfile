FROM alpine:3.18.6

EXPOSE 22 80 443 1180 11443

# Install some tools in the container and generate self-signed SSL certificates.
# Packages are listed in alphabetical order, for ease of readability and ease of maintenance.
RUN     apk update \
    &&  apk add apache2-utils bash bind-tools busybox-extras bonding curl \
                dnsmasq dropbear ethtool freeradius git go ifupdown-ng iperf iperf3 \
                iproute2 iputils jq lftp mtr mysql-client net-tools netcat-openbsd \
                nginx nmap openntpd openssh-client openssl perl-net-telnet \
                postgresql-client procps rsync socat sudo tcpdump tcptraceroute \
                tshark wget \
    &&  mkdir /certs /docker \
    &&  chmod 700 /certs \
    &&  openssl req \
        -x509 -newkey rsa:2048 -nodes -days 3650 \
        -keyout /certs/server.key -out /certs/server.crt -subj '/CN=localhost'

RUN wget https://github.com/osrg/gobgp/releases/download/v3.25.0/gobgp_3.25.0_linux_amd64.tar.gz
RUN mkdir -p /usr/local/gobgp
RUN tar -C /usr/local/gobgp -xzf gobgp_3.25.0_linux_amd64.tar.gz
RUN cp /usr/local/gobgp/gobgp* /usr/bin/

ENV GOROOT /usr/lib/go
ENV GOPATH /go

###
# set a password to SSH into the docker container with
RUN adduser -D -h /home/user user
RUN adduser user wheel
RUN sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
RUN echo 'user:multit00l' | chpasswd
#RUN echo 'root:alpine' | chpasswd
###

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf

COPY entrypoint.sh /docker/entrypoint.sh

# Start nginx in foreground (pass CMD to docker entrypoint.sh):
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

# Note: If you have not included the "bash" package, then it is "mandatory" to add "/bin/sh"
#         in the ENTNRYPOINT instruction.
#       Otherwise you will get strange errors when you try to run the container.
#       Such as:
#       standard_init_linux.go:219: exec user process caused: no such file or directory

# Run the startup script as ENTRYPOINT, which does few things and then starts nginx.
ENTRYPOINT ["/bin/sh", "/docker/entrypoint.sh"]






