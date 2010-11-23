use strict;
use warnings;
use Test::More;
BEGIN {
    require_ok('Dainamo');
    require_ok('Dainamo::Profile');
    require_ok('Dainamo::ProfileGroup');
};

subtest 'about new' => sub {
    my $dainamo = Dainamo->new;
    isa_ok($dainamo, 'Dainamo');
    done_testing;
};

subtest 'about add_profile ' => sub {
    my $dainamo = Dainamo->new;
    is(scalar @{ $dainamo->profiles }, 0, '$dainamo should have no profiles');
    $dainamo->add_profile(profile => Dainamo::Profile->new, weight => 1.0);
    my $profile = pop @{ $dainamo->profiles };
    isa_ok($profile, 'Dainamo::Profile');

    done_testing;
};

subtest 'about add_profile_group' => sub {
    my $dainamo = Dainamo->new;
    my $profile_group = Dainamo::ProfileGroup->new;
    $profile_group->add_profile(profile => Dainamo::Profile->new, weight => 1.0);
    is(scalar @{ $dainamo->profiles }, 0, '$dainamo should have no profiles');
    $dainamo->add_profile_group(group => $profile_group);

    my $profile = pop @{ $dainamo->profiles };
    isa_ok($profile, 'Dainamo::Profile');

    done_testing;
};

subtest 'about load_profiles' => sub {
    subtest 'success case' => sub {
        my $dainamo = Dainamo->new;

        eval {
            $dainamo->load_profiles('t/load_profile_conf/success.pl');
        };
        is($@, "", "should not fail");
        
        my $profile = pop @{ $dainamo->profiles };
        isa_ok($profile, 'Dainamo::Profile');
    };

    subtest 'in case not return ProfileGroup instance' => sub {
        for my $file ( qw[
            t/load_profile_conf/not_return_profile_group_instance.pl
            t/load_profile_conf/not_return_profile_group_instance2.pl
        ] ) {
            subtest $file => sub {
                my $dainamo = Dainamo->new;
                eval {
                    $dainamo->load_profiles('t/load_profile_conf/not_return_profile_group_instance.pl');
                };
                like($@, qr/should evaluate Dainamo::ProfileGroup /, 'should show some error message about ProfileGroup');

                done_testing;
            };
        }

        done_testing;
    };

    done_testing;
};

done_testing;
