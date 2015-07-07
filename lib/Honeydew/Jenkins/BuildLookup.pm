package Honeydew::Jenkins::BuildLookup;

use strict;
use warnings;

use feature qw/state/;
use DBD::MySQL;
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

has ua => (
    is => 'lazy',
    default => sub {
        return HTTP::Tiny->new;
    }
);

sub get_builds {
    my ($self, %args) = @_;

    my $url = $self->_get_runner_url( %args );
    my $builds = $self->__get_json( url => $url );
}

sub __get_json {
    my ($self, %args) = @_;
    my $ua = $self->ua;

    my $options = $self->__get_jenkins_headers;

    my $res = $ua->get( $args{url}, $options );
    return from_json( $res->{content} );
}

sub __get_jenkins_headers {
    my ($self) = @_;

    state $options = {
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
