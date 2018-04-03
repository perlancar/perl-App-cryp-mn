package App::cryp::mn;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Manage your masternodes',
};

$SPEC{list} = {
    v => 1.1,
    summary => 'List your masternodes',
    args => {
        detail => {
            schema => 'bool*',
            cmdline_aliases => {l=>{}},
        },
        with_status => {
            schema => 'bool*',
            cmdline_aliases => {s=>{}},
        },
    },
};
sub list {
    require CryptoCurrency::Catalog;
    require PERLANCAR::Module::List;

    my %args = @_;

    #use DDC; dd \%args;

    my $mods = PERLANCAR::Module::List::list_modules(
        "App::cryp::Masternode::", {list_modules=>1});

    my $cat = CryptoCurrency::Catalog->new;

    my @res;
    for my $mod (sort keys %$mods) {
        my ($safename) = $mod =~ /::(\w+)\z/;
        $safename =~ s/_/-/g;
        log_trace "Listing masternodes for $safename ...";
        my $coin = $cat->by_safename($safename);
        (my $mod_pm = "$mod.pm") =~ s!::!/!g; require $mod_pm;
        my $drv = $mod->new;
        my $res = $drv->list_masternodes(
            -cmdline_r => $args{-cmdline_r},
            detail => $args{detail} // 0,
            with_status => $args{with_status} // 0,
        );
        unless ($res->[0] == 200) {
            log_error "Couldn't list masternodes for %s: %s, skipped",
                $coin->{code}, $res;
            next;
        }
        for my $rec0 (@{$res->[2]}) {
            my $rec = {
                coin => $coin->{code},
            };
            if ($args{detail}) {
                $rec->{$_} = $rec0->{$_} for keys %$rec0;
            } else {
                $rec->{name} = $rec0;
            }
            push @res, $rec;
        }
    }

    my $resmeta = {
        'table.fields'        => [qw/coin name ip port collateral_txid collateral_oidx status active_time last_seen/],
        'table.field_formats' => [undef, undef, undef, undef, undef, undef, undef, undef, 'iso8601_datetime'],
    };

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Please see included script L<cryp-mn>.


=head1 SEE ALSO

L<App::cryp> and other C<App::cryp::*> modules.
