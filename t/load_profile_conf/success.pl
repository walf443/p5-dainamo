use strict;
use warnings;
use Dainamo::ProfileGroup;
use Dainamo::Profile;
my $group = Dainamo::ProfileGroup->new;

$group->add_profile(
    profile => Dainamo::Profile->new(
        name => 'foobar',
        max_requests_per_child => 10,
    ),
    weight => 1.0,
);

$group;
