package App::cryp::Masternode::zcoin;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use IPC::System::Options qw(system);
use JSON::MaybeXS;
use String::ShellQuote;

use Role::Tiny::With;
with 'App::cryp::Role::Masternode';

sub new {
    my ($package, %args) = @_;

    bless \%args, $package;
}

sub list_masternodes {
    my ($self, %args) = @_;

    my $crypconf = $args{-cmdline_r}{_cryp};
    my $conf     = $args{-cmdline_r}{config};

    my @res;

    # XXX read from cryp config

    # read from local wallet masternode config
    {
        my $conf_path = "$ENV{HOME}/.zcoin/znode.conf";
        unless (-f $conf_path) {
            log_debug "Couldn't find Zcoin wallet masternode configuration ".
                "file '$conf_path', skipped";
            last;
        }

        my $fh;
        unless (open $fh, "<", $conf_path) {
            log_error "Can't open '$conf_path': $!, skipped reading ".
                "Zcoin wallet masternode configuration file";
            last;
        }

        my $linum = 0;
        while (my $line = <$fh>) {
            $linum++;
            $line =~ /\S/ or next;
            $line =~ /^\s*#/ and next;
            $line =~ /^(\S+)\s+([0-9]+(?:\.[0-9]+){3}):([0-9]+)\s+(\S+)\s+(\S+)\s+(\d+)\s*$/ or do {
                log_warn "$conf_path:$linum: Doesn't match pattern, ignored";
                next;
            };
            push @res, {
                name => $1,
                ip   => $2,
                port => $3,
                collateral_txid => $5,
                collateral_oidx => $6,
            };
        }
        close $fh;

      CHECK_STATUS:
        {
            last unless $args{detail} && $args{with_status} && @res;

            # pick one masternode to ssh into
            my $rec = $res[rand @res];

            my $ssh_user =
                $crypconf->{masternodes}{zcoin}{$rec->{name}}{ssh_user} //
                $crypconf->{masternodes}{zcoin}{default}{ssh_user} //
                "root";
            my $mn_user  =
                $crypconf->{masternodes}{zcoin}{$rec->{name}}{mn_user} //
                $crypconf->{masternodes}{zcoin}{default}{mn_user} //
                $ssh_user; # XXX can also detect

            log_trace "ssh_user=<$ssh_user>, mn_user=<$mn_user>";

            if ($ssh_user ne 'root' && $ssh_user ne $mn_user) {
                log_error "Won't be able to access zcoin-cli (user $mn_user) while we SSH as $ssh_user, skipped";
                last;
            }

            my $ssh_timeout =
                $crypconf->{masternodes}{zcoin}{$rec->{name}}{ssh_timeout} //
                $crypconf->{masternodes}{zcoin}{default}{ssh_timeout} //
                $conf->{GLOBAL}{ssh_timeout} // 300;

            log_trace "SSH-ing to $rec->{name} ($rec->{ip}) as $ssh_user to query masternode status (timeout=$ssh_timeout) ...";

            eval {
                local $SIG{ALRM} = sub { die "Timeout\n" };
                # XXX doesn't cleanup ssh process when timeout triggers. same
                # with IPC::Cmd, or System::Timeout (which is based on
                # IPC::Cmd). IPC::Run's timeout doesn't work?
                alarm $ssh_timeout;

                my $ssh_cmd = $ssh_user eq $mn_user ?
                    "zcoin-cli znode list" :
                    "su $mn_user -c ".shell_quote("zcoin-cli znode list");

                my $output;
                system({log=>1, shell=>0, capture_stdout=>\$output},
                       "ssh", "-l", $ssh_user, $rec->{ip}, $ssh_cmd);

                my $output_decoded;
                eval { $output_decoded = JSON::MaybeXS->new->decode($output) };
                if ($@) {
                    log_error "Can't decode JSON output '$output', skipped";
                    last CHECK_STATUS;
                }

                for my $rec (@res) {
                    my $key = "COutPoint($rec->{collateral_txid}, $rec->{collateral_oidx})";
                    if (exists $output_decoded->{$key}) {
                        $rec->{status} = $output_decoded->{$key};
                    } else {
                        $rec->{status} = "(not found)";
                    }
                }
            };
            if ($@) {
                log_error "SSH timeout: $@, skipped";
                last;
            }
        } # CHECK_STATUS

        unless ($args{detail}) {
            @res = map {$_->{name}} @res;
        }

        [200, "OK", \@res];
    }
}

1;

# ABSTRACT: Zcoin (XZC) Masternode driver for App::cryp

=for Pod::Coverage ^(.+)$
