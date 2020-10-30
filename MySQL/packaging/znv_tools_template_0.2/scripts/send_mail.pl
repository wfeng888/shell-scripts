#!/usr/bin/perl -w
use Net::SMTP_auth;
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
}




my $mailhost = 'smtp.163.com';
my $mailfrom = '13502809065@163.com';
my @mailto   = ('0049003159@znv.com');

my $project = ' 项目 ${SUB_PROJECT_NAME} ';
my $address = get_ip_address("eth0");
my $user   = '13502809065@163.com';
my $passwd = 'Nokia2014';
my $title = ' 您好 ';


my $switch_to_master='SWITCH_TO_MASTER';
my $keepalived_down='KEEPALIVED_DOWN';
my $switch_to_backup='SWITCH_TO_BACKUP';
my $check_slave_status='CHECK_SLAVE_STATUS';
my $send_msg='SEND_MSG';
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
$year += 1900; 
$mon += 1; 
my $datetime = sprintf ("%d-%02d-%02d %02d:%02d:%02d", $year,$mon,$mday,$hour,$min,$sec);



my $text = " send_mail script running with errors .the current  machine is $address.\n Alert time is $datetime;";  

my $subject = $ARGV[0];
$subject  .= " keepalived alert at $datetime from $project .  please attention .";


my ($role) = $ARGV[1];
my ($port) = $ARGV[2];
$address="${address}:${port}";
if( defined $role && $role eq $keepalived_down ) {
	$text = " keepalived process has down from  machine  $address at $datetime .";
}
elsif( defined $role && $role eq $switch_to_master ) {
        $text = "keepalived has switched at $datetime , the current  machine's role  is master with address $address , please attention . ";
}
elsif( defined $role && $role eq $switch_to_backup ) {
	$text = "keepalived has switched at $datetime , the current  machine's role  is backup with address  $address , please attention . ";
}
elsif( defined $role && ( $role eq $check_slave_status || $role eq $send_msg )) {
	$text = $ARGV[3];
        $text .= " from machine $address at $datetime ";
}
else {
	print "wrong parameter !\n"
}

$text .= " \n\n\n\n project is $project ";
&SendMail();
##############################
# Send notice mail
##############################
sub SendMail() {
    my $smtp = Net::SMTP_auth->new( $mailhost, Timeout => 120, Debug => 0 )
      or die "Error.\n";
    $smtp->auth( 'LOGIN', $user, $passwd );
    foreach my $mailto (@mailto) {
        $smtp->mail($mailfrom);
        $smtp->to($mailto);
        $smtp->data();
        $smtp->datasend("To: $mailto\n");
        $smtp->datasend("From:$mailfrom\n");
        $smtp->datasend("Subject: $subject\n");
        $smtp->datasend("\n");
        $smtp->datasend("$text\n\n"); 
        $smtp->dataend();
    }
    $smtp->quit;
}
