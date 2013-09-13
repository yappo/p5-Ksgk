package package <ks: $module :gk>::Web::ViewFunctions;
use strict;
use warnings;
use utf8;
use parent 'Exporter';
use Module::Functions;

use Text::Xslate qw/html_escape mark_Raw/;

our @EXPORT = Module::Functions::get_public_functions;

:ksgk: INCLUDE('define_functions')

1;

