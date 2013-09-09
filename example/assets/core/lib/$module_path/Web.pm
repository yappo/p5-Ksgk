package <: $module :>::Web;
use strict;
use warnings;
use parent qw/<: $module :> Amon2::Web/;

__PACKAGE__->load_plugins(
: KSGK_INCLUDE('load_plugins')
);

__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my( $c ) = @_;

: KSGK_INCLUDE('before_dispatch')

        return;
    },
);

: KSGK_INCLUDE('define_methods')

1;
