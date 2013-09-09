: KSGK_CONTENTS('define_functions', -> {

sub l {
    my $base = shift;
    my @args = map { html_escape($_) } @_;
    mark_raw(<: $module :>->context->loc($base, @args));
}

: })
