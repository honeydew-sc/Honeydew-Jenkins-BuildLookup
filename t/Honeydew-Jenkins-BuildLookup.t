use strict;
use warnings;

use JSON;
use Honeydew::Jenkins::BuildLookup;
use Test::Spec;

describe 'Jenkins Build Lookup' => sub {
    my ($config, $jenkins, $mock_ua);
    before each => sub {
        $mock_ua = mock();
        $config = mock_config();

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
        is( $build_data->{builds}->[0]->{number}, 3033 );
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
        $jenkins->stubs( get_builds => {
            builds => [{
                number => 3033,
                url => 'jenkins_base_url/job/Sharecare-Build-Runner/3033/'
            }]
        } );
        $jenkins->stubs( is_build_successful => 1 );
        my $log =  <<LOG;
Checking out Revision (origin/branch)
/builds/sharecare/rc/build_number1234
LOG
        $jenkins->stubs( get_build_log => $log );

        my $result = $jenkins->get_build_branches;
        my $expected = [{
            branch => 'branch',
            build_number => 'build_number1234',
            count => 3033
        }];

        is_deeply( $result, $expected );
    };

    it 'should add authorization headers to the default ua' => sub {
        my $j = Honeydew::Jenkins::BuildLookup->new(
            config => $config,
            build_runners => [ 'test-runner' ]
        );
        my $ua = $j->ua;

        my $auth = $ua->default_headers->{authorization};
        is( $auth, 'Basic amVua2luc19hdXRo' );
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

    my $builds = {
        builds => [{
            number => 3033,
            url => 'jenkins_base_url/job/Sharecare-Build-Runner/3033/'
        }]
    };
    my $mock_builds_content = mock_http_response( $builds );

    $mock->expects('get')
      ->with_deep( 'jenkins_base_url/job/test-runner/api/json?tree=builds[url,number]' )
      ->returns( $mock_builds_content );

    return $mock;
}

sub mock_http_response {
    my ($content) = @_;


    my $res = $content;
    eval { $res = to_json( $content ) };

    my $fake_res = mock();
    $fake_res->expects('content')
      ->returns( $res );

    return $fake_res;
}

sub mock_build_result {
    my ($mock, $status) = @_;
    $status //= 'SUCCESS';

    my $result = { result => $status };
    my $http_response = mock_http_response( $result );

    $mock->expects('get')
      ->with_deep( 'build_url/api/json?tree=result' )
      ->returns( $http_response );

    return $mock;
}

sub mock_build_log {
    my ($mock) = @_;

    my $build_log =  <<LOG;
Checking out Revision (origin/branch)
/builds/sharecare/rc/build_number1234
LOG
    my $http_response = mock_http_response( $build_log );

    $mock->expects('get')
      ->with_deep( 'build_url/logText/progressiveText?start=0' )
      ->returns( $http_response );

    return $mock;
}

runtests;
