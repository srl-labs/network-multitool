ifup -a
#########
# create directories for ssh host keys
mkdir -p /etc/dropbear
# create the host keys
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key 2048
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key 512
dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key
# and start the process
/usr/sbin/dropbear -j -k -E -F &
#########
# Execute the command specified as CMD in Dockerfile:
exec "$@"
