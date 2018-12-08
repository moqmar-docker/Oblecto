FROM phusion/baseimage

COPY . /opt/oblecto
WORKDIR /opt/oblecto

# Install required dependencies (node.js, handbrake-cli, dbus, avahi, tools for node-gyp, lsof and netcat for init scripts)
RUN add-apt-repository --yes ppa:stebbins/handbrake-releases &&\
    curl -sL https://deb.nodesource.com/setup_11.x | bash - &&\
    apt-get upgrade -y -o Dpkg::Options::="--force-confold" &&\
    apt-get install -y avahi-daemon libavahi-compat-libdnssd-dev handbrake-cli avahi-discover libnss-mdns nodejs gcc g++ make netcat-traditional &&\
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install all node.js depencencies for Oblecto
RUN npm install

# Set up symlink to config.json and create init scripts for runit
RUN mkdir /data && rm src/config.json && ln -s /data/config.json src/config.json &&\
    echo "#!/bin/sh\nif ! [ -e /data/config.json ]; then\n  cp /opt/oblecto/src/config.docker.json /data/config.json\nfi\nrm -f /var/run/dbus/pid" > /etc/my_init.d/oblecto-default-config.sh &&\
    mkdir /etc/service/dbus /etc/service/avahi /etc/service/oblecto /var/run/dbus &&\
    echo "#!/bin/sh\nexec /usr/bin/dbus-daemon --system --nofork" > /etc/service/dbus/run &&\
    echo "#!/bin/sh\nif ! [ -e /var/run/dbus/system_bus_socket ]; then\n  exit 1\nfi\nexec /usr/sbin/avahi-daemon -s --debug --no-drop-root" > /etc/service/avahi/run &&\
    echo "#!/bin/sh\nif ! nc -zu 127.0.0.1 5353 || ! nc -z db 3306; then\n  exit 1\nfi\ncd /opt/oblecto\nexec /usr/bin/npm start" > /etc/service/oblecto/run &&\
    chmod +x /etc/service/dbus/run /etc/service/avahi/run /etc/service/oblecto/run /etc/my_init.d/oblecto-default-config.sh

EXPOSE 5353/udp
EXPOSE 80/tcp
CMD ["/sbin/my_init"]
