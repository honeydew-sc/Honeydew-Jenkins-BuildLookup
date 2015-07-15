package Honeydew::Jenkins::BuildLookup;

# ABSTRACT: Look up branches for build numbers on Jenkins
use strict;
use warnings;

use feature qw/state/;
use Honeydew::Config;
use HTTP::Tiny;
use JSON;
use MIME::Base64;
use Moo;

# ABSTRACT:

=for markdown [![Build Status](https://travis-ci.org/honeydew-sc/Honeydew-Jenkins-BuildLookup.svg?branch=master)](https://travis-ci.org/honeydew-sc/Honeydew-Jenkins-BuildLookup)

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

has config => (
    is => 'lazy',
    default => sub {
        return Honeydew::Config->instance;
    }
);

has jenkins_base_url => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;

        return $self->config->{jenkins}->{base_url};
    }
);

has jenkins_auth => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;

        my $auth = $self->config->{jenkins}->{auth};
        my $b64_auth = encode_base64($auth);
        chomp $b64_auth;
        return $b64_auth;
    }
);

has build_runners => (
    is => 'lazy',
    default => sub {
        return [ qw'Sharecare-Build-Runner' ]
    }
);

has ua => (
    is => 'lazy',
    default => sub {
        return HTTP::Tiny->new;
    }
);

sub get_build_branches {
    my ($self) = @_;

    my @runners = @{ $self->build_runners };

    my @branches;
    foreach my $runner (@runners) {
        my $builds = $self->get_builds( runner => $runner );

        my @build_branches = map {
            my ( $branch, $build_number ) = $self->parse_build_log( %{ $_ } );

            my $ret = {
                branch => $branch,
                build_number => $build_number,
                count => $_->{number}
            };

            $ret
        } grep {
            $self->is_build_successful( %{ $_ } )
        } @{ $builds->{builds } };

        push @branches, @build_branches;
    }

    return \@branches;
}

sub get_builds {
    my ($self, %args) = @_;

    my $url = $self->_get_runner_url( %args );
    my $builds = $self->_get_json( url => $url );

    return $builds;
}

sub is_build_successful {
    my ($self, %build) = @_;
    my $url = $build{url};

    my $status_url = $url . 'api/json?tree=result';
    my $content = $self->_get_json( url => $status_url);

    my $build_status = $content->{result} eq 'SUCCESS';
    return $build_status
}

sub parse_build_log {
    my ($self, %build) = @_;
    my $log = $self->get_build_log( %build );

    my ($branch, $build_number);
    if ($log =~ /Checking out Revision .*\(origin\/(.*)\)/) {
        $branch = $1;
    }

    if ($log =~ /\/builds\/sharecare\/rc\/(.*\d{4})/) {
        $build_number = $1 . "";
    }

    return ( $branch, $build_number );
}

sub get_build_log {
    my ($self, %build) = @_;

    my $url = $build{url};
    my $console_url = $url . 'logText/progressiveText?start=0';
    return $self->_get_url( url => $console_url );
}

sub _get_json {
    my ($self, %args) = @_;

    return from_json( $self->_get_url( %args ) );
}

sub _get_url {
    my ($self, %args) = @_;

    my $ua = $self->ua;
    state $options = $self->_get_jenkins_headers;

    my $res = $ua->get( $args{url}, $options );
    return $res->{content};
}

sub _get_jenkins_headers {
    my ($self) = @_;

    my $options = {
        headers => {
            Authorization => 'Basic ' . $self->jenkins_auth
        }
    };

    return $options;
}

sub _get_runner_url {
    my ($self, %args) = @_;
    my $runner = $args{runner};

    my $base = $self->jenkins_base_url;

    return $base .
      '/job/' .
      $runner .
      '/api/json?tree=builds[url,number]';
}

1;
