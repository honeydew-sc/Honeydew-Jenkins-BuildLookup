package Honeydew::Jenkins::Persist;

# ABSTRACT: Persist build-branch data to a mysql table

use Cwd qw/abs_path/;
use File::Basename qw/dirname/;
use DBI;
use Moo;
use Honeydew::Config;

has dbh => (
    is => 'lazy',
    default => sub {
        my ($self) = @_;
        my $dbh = DBI->connect( $self->config->mysql_dsn );
        return $dbh;
    }
);

has config => (
    is => 'lazy',
    default => sub {
        return Honeydew::Config->instance;
    }
);

sub create_table {
    my ($self) = @_;
    my $dbh = $self->dbh;
    my $create_sql_file = abs_path(dirname(__FILE__) . '/create.sql');

    open (my $fh, '<', $create_sql_file);
    my $create_sql = join( '', <$fh> );
    close ($fh);

    my $sth = $dbh->prepare( $create_sql );
    $sth->execute;

    return $create_sql;
}

sub add_build_branch {
    my ($self, %build) = @_;
    return unless $build{build_number};
    my $dbh = $self->dbh;

    my @fields = qw/branch count build_number/;
    my @values = ( $build{branch}, $build{count}, $build{build_number} );

    my $fields = join( ',',  @fields);
    my $values = join( ',', ('?') x (scalar @fields) );
    my $sql = "INSERT IGNORE INTO `jenkins` ($fields) VALUES ($values)";
    my $sth = $dbh->prepare( $sql );
    $sth->execute( @values );

    return $sql;
}

sub find_new_builds {
    my ($self, $builds) = @_;
    return unless scalar @$builds;

    my @build_numbers = map { $_->{build_number} } grep { $_->{build_number} }  @$builds;
    my $fields = join(', ', map { '?' } @build_numbers );

    my $sql = 'SELECT build_number FROM `jenkins` where build_number in ( ' . $fields . ' )';
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( @build_numbers );

    my $ret = $sth->fetchall_hashref( 'build_number' );
    my @found_builds = keys %$ret;

    my %in_database = map { $_ => 1 } @found_builds;
    return [ grep {
        my $build_number = $_->{build_number};
        not $in_database{$build_number}
    } @$builds ]
}

1;
