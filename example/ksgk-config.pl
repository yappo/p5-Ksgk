+{
    core_dir  => 'core',
    roles => [
        +{
            name    => 'basic',
            options => [qw/ l10n foo /],
        },
        +{
            name    => 'lite',
            options => [],
        },
    ],

    hooks => {
        before => sub {
            my $ksgk = shift;
        },
        after => sub {
            my $ksgk = shift;
        },
        # choose_role          => sub {},
        # choose_options       => sub {},
        # read_template_config => sub {},
    },

    template_config => +{
        hooks => {
            init  => sub {
                my($conf, $ksgk) = @_;
                $conf->{module} = $conf->{application_name};
            },
            finalize => sub {
                my($conf, $ksgk) = @_;
            },
        },
        core  => [
            +{
                name        => 'module',
                description => 'application module name',
                default     => sub { $_[0]->{module} },
            },
            +{
                name        => 'application_name',
                description => 'application name. use for repository name, service domain name',
                default      => sub {
                    my($conf, $ksgk) = @_;
                    join '_', split(/::/, $ksgk->decamelize($conf->{module}));
                },
            },
            +{
                name        => 'module_path',
                description => 'application module file path',
                default      => sub { join '/', split(/::/, $_[0]->{module}) },
            },
            +{
                name        => 'service_domain',
                description => 'domain name for production service',
                default      => sub { $_[0]->{application_name} . '.example.com' },
            },
        ],
        roles => {
            basic => [
                +{
                    name        => 'development_domain',
                    description => 'domain name for development',
                    default      => sub { $_[0]->{application_name} . '.develop.example.com' },
                },
            ],
        },
    },
};

