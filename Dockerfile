FROM alpine:3.18.6 AS builder

RUN apk update && apk add --virtual .build-deps \
    build-base gcc wget cmake cunit-dev libpcap-dev \
    ncurses-dev openssl-dev jansson-dev numactl-dev \ 
    libbsd-dev linux-headers

#Install bngblaster from source
RUN mkdir /bngblaster
WORKDIR /bngblaster
RUN wget https://github.com/rtbrick/libdict/archive/refs/tags/1.0.4.zip
RUN unzip 1.0.4.zip
RUN mkdir libdict-1.0.4/build
WORKDIR /bngblaster/libdict-1.0.4/build
RUN cmake ..
RUN make -j16 install
WORKDIR /bngblaster
RUN wget https://github.com/rtbrick/bngblaster/archive/refs/tags/0.9.26.zip
RUN unzip 0.9.26.zip
RUN mkdir bngblaster-0.9.26/build
WORKDIR /bngblaster/bngblaster-0.9.26/build
#remove redundant include to avoid preprocessor redirect warning and consequent compilation failure
RUN sed -i '/#include <sys\/signal.h>/d' ../code/lwip/contrib/ports/unix/port/netif/sio.c
#typedef for uint to avoid compilation error on alpine musl libc
RUN sed -i '$i typedef unsigned int uint;' ../code/common/src/common.h
# add include to support be32toh and htobe32 on alpine musl libc
RUN sed -i '/#include <stdlib.h>/i #include <endian.h>' ../code/common/src/common.h 
#replace __time_t with time_t to make it compatible with alpine musl libc
RUN find /bngblaster/bngblaster-0.9.26/code/ -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's/\b__time_t\b/time_t/g' {} +
#Don't error on sequence-point errors to allow build to complete on musl libc. Ideally code should be fixed on upstream repo.
RUN sed -i 's/APPEND CMAKE_C_FLAGS "-pthread"/APPEND CMAKE_C_FLAGS "-pthread -Wno-error=sequence-point"/' ../code/bngblaster/CMakeLists.txt
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBNGBLASTER_VERSION=0.9.26 ..
RUN make install

# Install mcjoin from source
WORKDIR /
RUN wget https://github.com/troglobit/mcjoin/releases/download/v2.12/mcjoin-2.12.tar.gz
RUN tar -xzf mcjoin-2.12.tar.gz
WORKDIR /mcjoin-2.12
RUN ./configure
RUN make -j5
RUN make install-strip

# Build stage for GoTTY
FROM golang:alpine AS gotty-builder

# Install git for go install to fetch the repository
RUN apk add --no-cache git

# Install GoTTY from source
RUN go install github.com/sorenisanerd/gotty@v1.5.0

# Final image
FROM alpine:3.18.6

EXPOSE 22 80 443 1180 11443 8080

# Install some tools in the container and generate self-signed SSL certificates.
# Packages are listed in alphabetical order, for ease of readability and ease of maintenance.
RUN     apk update \
    &&  apk add apache2-utils bash bind-tools busybox-extras bonding curl \
    dnsmasq dropbear ethtool freeradius git go ifupdown-ng iperf iperf3 \
    iproute2 iputils jq lftp mtr mysql-client net-tools netcat-openbsd \
    nginx nmap openntpd openssh-client openssl perl-net-telnet \
    postgresql-client procps rsync socat sudo tcpdump tcptraceroute \
    tshark wget envsubst scapy liboping fping bash-completion \
    &&  mkdir /certs /docker \
    &&  chmod 700 /certs \
    &&  openssl req \
    -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout /certs/server.key -out /certs/server.crt -subj '/CN=localhost'

RUN wget https://github.com/osrg/gobgp/releases/download/v3.25.0/gobgp_3.25.0_linux_amd64.tar.gz
RUN mkdir -p /usr/local/gobgp
RUN tar -C /usr/local/gobgp -xzf gobgp_3.25.0_linux_amd64.tar.gz
RUN cp /usr/local/gobgp/gobgp* /usr/bin/

COPY --from=builder /usr/local/bin/mcjoin /usr/local/bin/
COPY --from=builder /usr/sbin/bngblaster-cli /usr/sbin/
COPY --from=builder /usr/bin/bgpupdate /usr/bin/
COPY --from=builder /usr/bin/ldpupdate /usr/bin/
COPY --from=builder /usr/sbin/bngblaster /usr/sbin/
COPY --from=builder /usr/sbin/lspgen /usr/sbin/
RUN mkdir /run/lock

RUN rm /etc/motd

###
# set a password to SSH into the docker container with
RUN adduser -D -h /home/admin -s /bin/bash admin
RUN adduser admin wheel
RUN sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
RUN echo 'admin:multit00l' | chpasswd
# copy a basic but nicer than standard bashrc for the user 'admin'
COPY .bashrc /home/admin/.bashrc
RUN chown admin:admin /home/admin/.bashrc
# Ensure .bashrc is sourced by creating a .bash_profile that sources .bashrc
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /home/admin/.bash_profile
# Ensure configs in /etc/ssh/ssh_config.d/ are included
RUN echo "Include /etc/ssh/ssh_config.d/*" >> /etc/ssh/ssh_config
# Change ownership of the home directory to the user 'admin'
RUN chown -R admin:admin /home/admin
###

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf

# copy the bashrc file to the root user's home directory
COPY .bashrc /root/.bashrc
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /root/.bash_profile

# Copy GoTTY binary from the build stage
COPY --from=gotty-builder /go/bin/gotty /usr/local/bin/
RUN chmod +x /usr/local/bin/gotty

# Create directories for GoTTY service
RUN mkdir -p /var/run/gotty /var/log/gotty

COPY gotty-service /usr/local/bin/gotty-service
RUN chmod +x /usr/local/bin/gotty-service

COPY entrypoint.sh /docker/entrypoint.sh
COPY if-wait.sh /docker/if-wait.sh

# Start nginx in foreground (pass CMD to docker entrypoint.sh):
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

# Run the startup script as ENTRYPOINT, which does few things and then starts nginx.
ENTRYPOINT ["/bin/sh", "/docker/entrypoint.sh"]
