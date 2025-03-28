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
    tshark wget envsubst scapy make liboping fping\
    &&  mkdir /certs /docker \
    &&  chmod 700 /certs \
    &&  openssl req \
    -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout /certs/server.key -out /certs/server.crt -subj '/CN=localhost'

RUN wget https://github.com/osrg/gobgp/releases/download/v3.25.0/gobgp_3.25.0_linux_amd64.tar.gz
RUN mkdir -p /usr/local/gobgp
RUN tar -C /usr/local/gobgp -xzf gobgp_3.25.0_linux_amd64.tar.gz
RUN cp /usr/local/gobgp/gobgp* /usr/bin/

RUN wget https://github.com/troglobit/mcjoin/releases/download/v2.11/mcjoin-2.11.tar.gz
RUN tar -C /tmp/ -xzf mcjoin-2.11.tar.gz
WORKDIR /tmp/mcjoin-2.11
RUN ./configure
RUN make -j5
RUN make install-strip
WORKDIR /
RUN rm -rf /tmp/mcjoin-2.11

RUN rm /etc/motd

###
# set a password to SSH into the docker container with
RUN adduser -D -h /home/user -s /bin/bash user
RUN adduser user wheel
RUN sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
RUN echo 'user:multit00l' | chpasswd
# copy a basic but nicer than standard bashrc for the user
COPY .bashrc /home/user/.bashrc
RUN chown user:user /home/user/.bashrc
# Ensure .bashrc is sourced by creating a .bash_profile that sources .bashrc
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /home/user/.bash_profile

# Change ownership of the home directory to the user
RUN chown -R user:user /home/user
###

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf

# copy the bashrc file to the root user's home directory
COPY .bashrc /root/.bashrc
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /root/.bash_profile

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






