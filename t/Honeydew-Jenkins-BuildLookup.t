use strict;
use warnings;

use JSON;
use Honeydew::Jenkins::BuildLookup;
use Test::Spec;

describe 'Jenkins Build Lookup' => sub {
    my ($jenkins, $mock_ua);
    before each => sub {
        $mock_ua = mock();
        my $config = mock_config();
        $jenkins = Honeydew::Jenkins::BuildLookup->new(
            ua => $mock_ua,
            config => $config,
            build_runners => [ 'test-runner' ]
        );
    };

    it 'should construct build runner urls' => sub {
        my $runners = $jenkins->_get_runner_url( runner => 'test-runner' );
        like( $runners, qr{job/test-runner/api/json\?tree=builds\[url,number\]} );
    };

    it 'should get builds for a runner' => sub {
        mock_builds( $mock_ua );
        my $build_data = $jenkins->get_builds( runner => 'test-runner' );
        is( $build_data->[0]->{number}, 3033 );
    };

    it 'should check if builds are successful' => sub {
        mock_build_result( $mock_ua );

        my $is_success = $jenkins->is_build_successful( url => 'build_url/' );
        ok( $is_success );
    };

    it 'should check if builds have failed' => sub {
        mock_build_result( $mock_ua, 'FAILURE' );

        my $is_success = $jenkins->is_build_successful( url => 'build_url/' );
        ok( ! $is_success );
    };

    it 'should get the branch and build number for a build' => sub {
        mock_build_log( $mock_ua );

        my ( $branch, $build_number ) = $jenkins->parse_build_log( url => 'build_url/' );
        is( $branch, 'branch' );
        is( $build_number, 'build_number1234' );
    };

    it 'should get records for all of the builds on a runner' => sub {
        $jenkins->stubs( get_builds => mock_builds_content() );
        $jenkins->stubs( is_build_successful => 1 );
        $jenkins->stubs( get_build_log => mock_build_log_content() );

        my $result = $jenkins->get_build_branches;
        my $expected = [{
            branch => 'branch',
            build_number => 'build_number1234',
            count => 3033
        }];

        is_deeply( $result, $expected );
    };


};

sub mock_config {
    return {
        jenkins => {
            base_url => 'jenkins_base_url',
            auth => 'jenkins_auth'
        }
    };
}

sub mock_builds {
    my ($mock) = @_;

    my $mock_builds_content = mock_builds_content();

    $mock->expects('get')
      ->with_deep( 'jenkins_base_url/job/test-runner/api/json?tree=builds[url,number]', mock_basic_auth() )
      ->returns({ content => to_json($mock_builds_content) });

    return $mock;
}

sub mock_builds_content {
    return [{
        number => 3033,
        url => 'jenkins_base_url/job/Sharecare-Build-Runner/3033/'
    }];
}

sub mock_build_result {
    my ($mock, $status) = @_;
    $status //= 'SUCCESS';

    $mock->expects('get')
      ->with_deep( 'build_url/api/json?tree=result', mock_basic_auth() )
      ->returns({ content => '{"result":"' . $status . '"}'});

    return $mock;
}

sub mock_basic_auth {
    return {
        headers => {
            Authorization => 'Basic amVua2luc19hdXRo'
        }
    };
}

sub mock_build_log {
    my ($mock) = @_;

    my $mock_log = mock_build_log_content();

    $mock->expects('get')
      ->with_deep( 'build_url/logText/progressiveText?start=0', mock_basic_auth() )
      ->returns({ content => $mock_log });

    return $mock;
}

sub mock_build_log_content {
    return <<LOG;
Checking out Revision (origin/branch)
/builds/sharecare/rc/build_number1234
LOG
}

runtests;
