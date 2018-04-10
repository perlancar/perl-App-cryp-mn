package App::cryp::Role::Masternode;

use 5.010001;
use strict;
use warnings;

use Role::Tiny;

requires qw(
               new
               list_masternodes
       );

1;
# ABSTRACT: Role for Masternode drivers

=head1 PROVIDED METHODS

=head1 REQUIRED METHODS

=head2 new

Usage:

 new(%args) => obj

Constructor. Known arguments:

=over

=back

=head2 list_masternodes

Usage: $mn->list_masternodes => [$status, $reason, $payload, \%resmeta]

List all masternodes.

Method must return enveloped result. Payload must be an array containing
masternode names (except when C<detail> argument is set to true, in which case
method must return array of records/hashrefs).

Known options:

=over

=item * detail

Boolean. Default 0. If set to 1, method must return array of records/hashrefs
instead of just array of strings (masternode names).

Record must contain these keys: C<name> (str), C<ip> (IP address, str), C<port>
(port number, uint16). C<collateral_txid> (collateral transaction ID, str),
C<collateral_oidx> (collateral's output index in collateral transaction, uint).
Record can contain additional keys.

=item * with_status

Boolean. Default 0. Only relevant when detail=1.

If set to true, method must return additional record keys: C<status> (str).

Querying status requires querying the list/masternode, so this is not done by
default.

=back
