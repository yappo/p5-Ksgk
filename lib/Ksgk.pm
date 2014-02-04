package Ksgk;
use strict;
use warnings;
use 5.008_005;
our $VERSION = '0.01';

use Caroline;
use Data::Dumper ();
use File::Spec;
use File::stat;
use String::CamelCase ();
use Path::Tiny ();
use Text::Xslate;
use File::Copy ();
use Carp ();

use Class::Accessor::Lite (
    ro => [qw/ argv cwd config assets_dir application_root role_options template_config role files /],
);

sub decamelize {
    my(undef, $text) = @_;
    String::CamelCase::decamelize($text);
}

sub assets_root {
    my($self, @path) = @_;
    Path::Tiny::path($self->assets_dir, @path);
}

sub target_root {
    my($self, @path) = @_;
    Path::Tiny::path($self->application_root, @path);
}

sub make_dir {
    my($self, $path) = @_;
    return if -d $path;
    print "mkdir $path 0777\n";
    $path->mkpath(
        mode => 0777
    );
}

sub change_dir {
    my($self, $path) = @_;
    print "cd $path\n";
    chdir $path;
}

sub change_cwd_dir {
    my $self = shift;
    $self->change_dir($self->cwd);
}

sub change_target_dir {
    my $self = shift;
    $self->change_dir($self->cwd);
    $self->change_dir($self->target_root(@_));
}

sub prompt_yn {
    my($self, $text) = @_;

    while (defined(my $line = $self->{readline}->readline($text . ' [yN]: '))) {
        chomp $line;
        return 'n' unless $line =~ /\Ay\z/i;
        return 'y';
    }
}

sub run_callback {
    my($self, $callback, $default, @args) = @_;
    return $default unless $callback && ref($callback) eq 'CODE';
    $callback->(@args);
}

sub command {
    my($self, @args) = @_;

    my $cmd = join ' ', @args;
    print "\$ $cmd\n";
    !system(@args) or die $!;
}

sub dump_ksgk_config {
    my $self = shift;
    my %data = %{ $self };

    for my $key (qw/ readline xslate xslate_data cwd assets_dir files config /) {
        delete $data{$key};
    }

    $self->make_dir($self->target_root);
    my $file = $self->target_root('ksgk.conf');
    open my $fh, '>', $file or die "$!: $file";
    print $fh Data::Dumper->new([ \%data ])->Terse(1)->Sortkeys(1)->Dump;
    close $fh;
}

sub has_role_option {
    my($self, $name) = @_;
    grep { $_ eq $name } @{ $self->role_options };
}

sub new {
    my($class, %args) = @_;

    my $self = bless {
        argv         => $args{argv},
        cwd          => Path::Tiny->cwd(),
        config       => $args{config},
        assets_dir   => $args{assets_dir},
        readline     => Caroline->new,
        role         => '',
        role_options => [],
        xslate_data  => undef,
        tag_start    => ($args{tag_start}  || '<ks:'),
        tag_end      => ($args{tag_end}    || ':gk>'),
        line_start   => ($args{line_start} || ':ksgk:'),
        output_layer => (defined $args{output_layer} ? $args{output_layer} : ':utf8'),
    }, $class;

    my $include = sub {
        my($is_separate, $start, $end, $name, @args) = @_;
        my $contents = '';
        if (defined $self->{xslate_data}{$name}) {
            $contents = join '', map {
                my $text = $_->(@args);
                $text =~ s/(\r?\n)\z/$1$1/ if $is_separate;
                $text;
            } @{ $self->{xslate_data}{$name} };
        }
        my $separater = ($contents =~ /\r/) ? "\r\n" : "\n";
        $contents =~ s/\r?\n\z//;
        $contents =~ s/\r?\n\z// if $is_separate;

        my $function_name = $is_separate ? 'INCLUDE' : 'INCLUDE_ZERO_SEPARATE';
        return join($separater, "${start}$self->{line_start} $function_name('$name') # BEFORE$end", $contents, "${start}$self->{line_start} $function_name('$name') # AFTER$end") . $separater;
    };

    $self->{xslate} = Text::Xslate->new(
        tag_start  => $self->{tag_start},
        tag_end    => $self->{tag_end},
        line_start => $self->{line_start},
        %{ $args{xslate_options} || +{} },
        path     => $self->assets_root,
        syntax   => 'Kolon',
        type     => 'text', # use unmark_raw
        function => +{
            CONTENTS              => sub {
                my($name, $contents) = @_;
                $self->{xslate_data}{$name} = [] unless defined $self->{xslate_data}{$name};
                push @{ $self->{xslate_data}{$name} }, $contents;
            },
            INCLUDE                            => sub { $include->(1, '# ', '', @_) },
            INCLUDE_ZERO_SEPARATE              => sub { $include->(0, '# ', '',  @_) },
            INCLUDE_WITH_COMMENT               => sub { $include->(1, @_) },
            INCLUDE_ZERO_SEPARATE_WITH_COMMENT => sub { $include->(0, @_) },
        }
    );

    my $hooks = $self->config->{hooks} || +{};
    for my $name (qw/ choose_role choose_options read_template_config /) {
        if ($hooks->{$name} && ref($hooks->{$name}) eq 'CODE') {
            $self->{+{
                choose_role          => 'role',
                choose_options       => 'role_options',
                read_template_config => 'template_config',
            }->{$name}} = $hooks->{$name}($self);
        } else {
            $self->$name()
        }
    }

    $self->{application_root} = $self->template_config->{application_name};

    $self;
}

sub choose_role {
    my $self = shift;

    my @roles;
    my $idx = 1;
    for my $role (@{ $self->config->{roles} }) {
        push @roles, $role->{name};
        printf "% 3d: %s - %s\n", $idx++, $role->{name}, $role->{description};
    }
    while (defined(my $line = $self->{readline}->readline("Choose Template Role [1-@{ [ scalar(@roles) ] }]: "))) {
        chomp $line;
        next unless $line =~ /\A[0-9]+\z/;

        my $role = $roles[$line - 1];
        next unless $role;

        $self->{role} = $role;
        last;
    }
}

sub choose_options {
    my $self = shift;
    my @options = map { @{ $_->{options} } } grep { $_->{name} eq $self->role } @{ $self->config->{roles} };
    return unless @options;

    my %choose;
    my $make_ask_text = sub {
        my $text = '';
        my $idx = 1;
        for my $name (@options) {
            $text .= sprintf "[%s] % 3d: %s - %s\r\n", ($choose{$name} ? '*' : ' '), $idx, $name, $self->config->{options}{$name}{description};
            $idx++;
        }
        $idx--;

        print $text;
        "Choose Role Options [1-$idx] (0 = ready to proceed): "
    };

    while (defined(my $line = $self->{readline}->readline($make_ask_text->()))) {
        chomp $line;
        next unless $line =~ /\A[0-9]+\z/;
        last if $line eq '0';

        my $name = $options[$line - 1];
        next unless $name;
        $choose{$name} = 1 unless delete $choose{$name}; # xor switch
    }

    for my $name (@options) {
        push @{ $self->{role_options} }, $name if $choose{$name};
    }
}

sub read_template_config {
    my $self = shift;

    my $template_config = $self->config->{template_config};
    my $config = +{
        application_name => shift @{ $self->argv },
    };

    unless (defined $config->{application_name}) {
        Carp::croak('Application name was not specified (in argv[0]).');
    }

    $self->run_callback($template_config->{hooks}{init}, undef, $config, $self);

    my @options_config = map {
        @{ $template_config->{options}{$_} || [] }
    } @{ $self->role_options };

    for my $conf (@{ $template_config->{core} || [] }, @{ $template_config->{roles}{$self->role} || [] }, @options_config) {
        my $default = $conf->{default};
        $default = $self->run_callback($default, $default, $config, $self);

        my $description = $conf->{description};
        while (defined(my $line = $self->{readline}->readline("$description [$default]: "))) {
            chomp $line;
            my $ret = $line || $default;
            next unless $self->run_callback($conf->{validation}, 1, $ret, $config, $self);
            $config->{$conf->{name}} = $ret;
            last;
        }
    }

    $self->run_callback($template_config->{hooks}{finalize}, undef, $config, $self);

    $self->{template_config} = $config;
}

sub run {
    my $self = shift;

    $self->run_callback($self->config->{hooks}{before}, undef, $self);
    
    $self->load_files;
    $self->write_files;

    $self->run_callback($self->config->{hooks}{after}, undef, $self);
}

sub load_files {
    my $self = shift;

    my $core_files = $self->collect_files($self->assets_root('core'));
    my $role_files = $self->collect_files($self->assets_root('roles', $self->role));

    my @options;
    for my $name (@{ $self->role_options }) {
        push @options, +{
            name  => $name,
            files => $self->collect_files($self->assets_root('options', $name))
        };
    }

    $self->{files} = {
        core    => $core_files,
        role    => $role_files,
        options => \@options,
    };
}

sub collect_files {
    my($self, $path) = @_;
    my $files = $self->_collect_files($path);

    my $new_files = {};
    for my $data (@{ $files }) {
        my($name, $write_name) = @{ $data };
        $new_files->{Path::Tiny::path($write_name)->relative($path)} = $name;
    }
    $new_files;
}

sub _collect_files {
    my($self, $path) = @_;

    my @files;
    for my $name ($path->children) {
        if (-d $name) {
            my $children_files = $self->_collect_files($name);
            push @files, @{ $children_files };
        } else {
            my $write_name = "$name";
            $write_name =~ s{\$([a-zA-Z_](?:[a-zA-Z0-9_])*)}{
                $self->template_config->{$1}
            }eg;
            push @files, [ $name, $write_name ];
        }
    }

    \@files;
}

sub write_files {
    my $self = shift;
    local $self->{_writed_files} = {};

    my @options = map { $_->{files} } @{ $self->files->{options} };
    $self->_write_files($self->files->{core}, $self->files->{role}, @options);
    $self->_write_files($self->files->{role}, @options);
    while (my $files = shift @options) {
        $self->_write_files($files, @options);
    }
}

sub _write_files {
    my($self, $base, @files) = @_;

    my $ignore_render_path = $self->config->{ignore_render_path};
    for my $name (sort keys %{ $base }) {
        my $path = $base->{$name};
        my $write_path = $self->target_root($name);
        next if $self->{_writed_files}{$write_path}++;
        if (-e $write_path) {
            next if $self->prompt_yn("$write_path exists. Override?") eq 'n';
        }
        my $stat = stat($path);

        local $self->{xslate_data} = +{};
        $self->make_include_data($name, @files);

        $self->make_dir($write_path->parent);

        my $template = $path->relative($self->assets_root);
        print "read base template $template\n";
        print "write file: $name\n";
        if ($ignore_render_path && $name =~ /$ignore_render_path/) {
            $self->assets_root($template)->copy($write_path);
        } else {
            open my $fh, ">$self->{output_layer}", $write_path
                or die "$!: $write_path";
            print $fh $self->{xslate}->render(
                $template, $self->template_config,
            );
            close $fh;
        }

        chmod $stat->mode, $write_path;
    }
}

sub make_include_data {
    my($self, $name, @files) = @_;

    my $data = {};
    my $assets_root = $self->assets_root;
    for my $file (@files) {
        my $path = $file->{$name};
        next unless $path;

        my $template = Path::Tiny::path($path)->relative($assets_root);
        print "read template contents $template\n";
        $self->{xslate}->render(
            $template, $self->template_config,
        );
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Ksgk - Knack of the System Generation for Kurouto

=head1 SYNOPSIS

see example directory.

=head1 DESCRIPTION

Ksgk is

=head1 AUTHOR

Kazuhiro Osawa E<lt>yappo {at} shibuya {dot} plE<gt>

=head1 COPYRIGHT

Copyright 2013- Kazuhiro Osawa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
