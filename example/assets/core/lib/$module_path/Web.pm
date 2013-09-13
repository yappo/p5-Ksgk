package <ks: $module :gk>::Web;
use strict;
use warnings;
use parent qw/<ks: $module :gk> Amon2::Web/;

__PACKAGE__->load_plugins(
:ksgk: INCLUDE_ZERO_SEPARATE('load_plugins')
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my( $c ) = @_;

:ksgk: INCLUDE('before_dispatch')

        return;
    },
);

:ksgk: INCLUDE('define_methods')

1;
