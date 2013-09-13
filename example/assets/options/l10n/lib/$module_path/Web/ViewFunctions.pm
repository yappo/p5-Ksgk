:ksgk: CONTENTS('define_functions', -> {
sub l {
    my $base = shift;
    my @args = map { html_escape($_) } @_;
    mark_raw(<ks: $module :gk>->context->loc($base, @args));
}
:ksgk: })
