package <ks: $module :gk>;
use strict;
use warnings;
use parent 'Amon2';

__PACKAGE__->load_plugins(
:ksgk: INCLUDE_ZERO_SEPARATE('load_plugins')
);

:ksgk: INCLUDE('define_methods')

1;
