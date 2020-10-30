 #!/usr/bin/perl
    use strict;
    use warnings;
    use Socket;
    require 'sys/ioctl.ph';
    sub get_ip_address($) {
        my $pack = pack("a*", shift);
        my $socket;
        socket($socket, AF_INET, SOCK_DGRAM, 0);
        ioctl($socket, SIOCGIFADDR(), $pack);
        return inet_ntoa(substr($pack,20,4));
    };
    print get_ip_address("eth0");
