#! /usr/bin/perl

use strict;
use warnings;

use Honeydew::Jenkins::Persist;
use Test::mysqld;
use Test::Spec;

describe 'MySQL Persistence' => sub {
    my ($mysqld, $dbh, $persist);

    before all => sub {
        $mysqld = Test::mysqld->new(
            my_cnf => {
                'skip-networking' => '', # no TCP socket
            }
        ) or plan skip_all =>  $Test::mysqld::errstr;

        $dbh = DBI->connect( $mysqld->dsn( dbname => 'test' ) );
    };

    before each => sub {
        $persist = Honeydew::Jenkins::Persist->new(
            dbh => $dbh
        );
    };

    it 'should create a build branch table' => sub {
        my $sql = $persist->create_table;

        my $sth = $dbh->prepare('select * from jenkins');
        $sth->execute;
        my $ret = $sth->fetchall_arrayref;
        is_deeply( $ret, [] );
    };

    it 'should insert new records into the db' => sub {
        my %build = (
            branch => 'branch',
            count => 1,
            build_number => 'build_number1234'
        );

        my %expected = ( %build, id => 1 );
        my $sql = $persist->add_build_branch( %build );

        my $sth = $dbh->prepare('select * from jenkins');
        $sth->execute;
        my $ret = $sth->fetchrow_hashref;

        is_deeply( $ret, \%expected );
    };

    it 'should determine which builds are new' => sub {
        my @builds = (
            {
                branch => 'branch',
                count => 1,
                build_number => 'build1'
            },
            {
                branch => 'branch',
                count => 2,
                build_number => 'build2'
            }
        );
        $persist->add_build_branch( %$_ ) for @builds;

        my $builds = [
            { build_number => 'build1' },
            { build_number => 'build2' },
            { build_number => 'build3' }
        ];

        my $new = $persist->find_new_builds( $builds );
        is_deeply( $new, [{ build_number => 'build3' }] );
    };

};

runtests;
