#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

use FindBin;
use File::Spec;

use Ksgk;

my $ksgk = Ksgk->new(
    argv       => \@ARGV,
    assets_dir => File::Spec->catfile($FindBin::Bin, 'assets'),
    config     => +{
        core_dir  => 'core',
        roles => [
            +{
                name        => 'basic',
                description => 'basic application',
                options     => [qw/ l10n apache foo /],
            },
            +{
                name        => 'lite',
                description => 'lite application',
                options     => [],
            },
        ],

        options => +{
            l10n => +{
                description => 'multi language',
            },
            apache => +{
                description => 'apache server config',
            },
            foo => +{
                description => 'foo',
            },
        },

        hooks => {
            before => sub {
                my $ksgk = shift;
            },
            after => sub {
                my $ksgk = shift;
                $ksgk->change_dir($ksgk->target_root);

                $ksgk->command(qw/ carton install /);
                $ksgk->command(qw/ carton check /);

                $ksgk->command(qw/ git init /);

                $ksgk->change_dir($ksgk->cwd);

                $ksgk->dump_ksgk_config;
            },
            # choose_role          => sub { my $ksgk = shift },
            # choose_options       => sub { my $ksgk = shift },
            # read_template_config => sub { my $ksgk = shift },
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
            ],
            roles => {
                basic => [
                    +{
                        name        => 'foo',
                        description => 'foo',
                        default      => sub { 'foo' },
                    },
                ],
            },
            options => {
                apache => [
                    +{
                        name        => 'service_domain',
                        description => 'domain name for production service',
                        default      => sub { $_[0]->{application_name} . '.example.com' },
                    },
                    +{
                        name        => 'development_domain',
                        description => 'domain name for development',
                        default      => sub { $_[0]->{application_name} . '.develop.example.com' },
                    },
                ],
            },
        },
    }
);
$ksgk->run;
