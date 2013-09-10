package <: $module :>;
use strict;
use warnings;
use parent 'Amon2';

__PACKAGE__->load_plugins(
: KSGK_INCLUDE_ZERO_SEPARATE('load_plugins')
);

: KSGK_INCLUDE('define_methods')

1;
