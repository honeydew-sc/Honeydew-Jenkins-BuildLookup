use strict;
use warnings;
use Test::Spec;
use Honeydew::Jenkins::BuildLookup;

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
        $mock_ua->expects('get')
          ->with_deep( 'jenkins_base_url/job/test-runner/api/json?tree=builds[url,number]', {
              headers => {
                  Authorization => 'Basic amVua2luc19hdXRo'
              }
          })
          ->returns({ content => '{"json":"json"}' });
        my $build_data = $jenkins->get_builds( runner => 'test-runner' );
        is_deeply( $build_data, { json => 'json' } );
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

runtests;
