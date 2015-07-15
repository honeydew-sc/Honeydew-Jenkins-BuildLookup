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
    my $dbh = $self->dbh;

    my @fields = qw/branch count build_number/;
    my @values = ( $build{branch}, $build{count}, $build{build_number} );

    my $fields = join( ',',  @fields);
    my $values = join( ',', ('?') x (scalar @fields) );
    my $sql = "INSERT INTO `jenkins` ($fields) VALUES ($values)";
    my $sth = $dbh->prepare( $sql );
    $sth->execute( @values );

    return $sql;
}

1;
