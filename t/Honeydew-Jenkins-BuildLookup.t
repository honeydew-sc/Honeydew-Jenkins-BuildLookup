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
            config => $config,
            ua => $mock_ua
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

    my $mock_builds_content = [{
        number => 3033,
        url => 'jenkins_base_url/job/Sharecare-Build-Runner/3033/'
    }];

    $mock->expects('get')
      ->with_deep( 'jenkins_base_url/job/test-runner/api/json?tree=builds[url,number]', mock_basic_auth() )
      ->returns({ content => to_json($mock_builds_content) });

    return $mock;
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

runtests;
