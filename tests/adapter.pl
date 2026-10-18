use strict;use warnings;use utf8;use JSON::PP;use Licensebox;
my $json=JSON::PP->new->utf8;local $/;my $r=$json->decode(<STDIN>);
sub run {
 return Licensebox::derive_binding(@$r{qw(product source raw_id)}) if $r->{op} eq 'derive';
 return Licensebox::native_binding($r->{product}) if $r->{op} eq 'native';
 return Licensebox::verify_lease(@$r{qw(token product keys now)}) if $r->{op} eq 'verify';
 my $c=Licensebox::Client->new(product=>$r->{product},keys=>$r->{keys},version=>'conformance',server=>$r->{server},ca_bundle=>$r->{ca_bundle},directory=>$r->{directory},hooks=>{clock=>sub{$r->{now}},machine_binding=>sub{$r->{binding}},on_sign_in=>sub{}});
 my $v;eval {my $op=$r->{op};
 if($op eq 'require'){$v=$c->require_module($r->{module}//'core')}
 elsif($op eq 'repeat'){$c->require_module('core');$v=$c->require_module('core')}
 elsif($op eq 'sign_in'){$v=$c->sign_in(3)}
 elsif($op eq 'request'){$v=$c->request_access(['export'],'café – test')}
 elsif($op eq 'access-link'){$v=$c->access_link}
 elsif($op eq 'record'){$c->record('export',1,.125);$c->record('export',0,.025);$v=undef}
 else{$v=$c->$op()}
 };my $e=$@;$c->close;die $e if $e;return $v;
}
my $v=eval{run()};my $e=$@;print $json->encode($e?{ok=>JSON::PP::false,error=>ref($e)?$e->{code}:'adapter_error'}:{ok=>JSON::PP::true,value=>$v}),"\n";
