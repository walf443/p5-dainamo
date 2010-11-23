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
};


done_testing;
