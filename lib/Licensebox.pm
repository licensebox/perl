package Licensebox;
use strict;use warnings;use JSON::PP ();use Encode qw(encode_utf8);use POSIX qw(isfinite);
our $VERSION='0.3.0';require XSLoader;XSLoader::load('Licensebox',$VERSION);
my $json=JSON::PP->new->utf8;
sub _arg {my($s)=@_;die bless({code=>'invalid_argument',message=>'NUL/undefined argument'},'Licensebox::Error') if !defined($s)||ref($s)||index($s,"\0")>=0;encode_utf8($s)}
sub _keys {my($keys)=@_;for(keys %$keys){_arg($_);_arg($keys->{$_})}$keys}
sub derive_binding {my($product,$source,$raw)=@_;$raw=~s/\0+$//;die bless({code=>'identity_unavailable'},'Licensebox::Error') if index($raw,"\0")>=0;Licensebox::Native::_derive(_arg($product),_arg($source),encode_utf8($raw))}
sub native_binding {Licensebox::Native::_native(_arg($_[0]))}
sub verify_lease {my($token,$product,$keys,$now)=@_;die bless({code=>'invalid_argument'},'Licensebox::Error') unless isfinite($now);$json->decode(Licensebox::Native::_verify(_arg($token),_arg($product),$json->encode(_keys($keys)),$now))}
package Licensebox::Error;
use overload '""'=>sub {'licensebox: '.($_[0]{message}//$_[0]{code})},fallback=>1;
sub code {$_[0]{code}}
package Licensebox::Client;
use strict;use warnings;use POSIX qw(isfinite);
sub new {
 my($class,%cfg)=@_;my $hooks=delete($cfg{hooks})||{};
 my %opts=(product=>$cfg{product},keys=>Licensebox::_keys($cfg{keys}),version=>$cfg{version}//'');
 for(qw(product version)){Licensebox::_arg($opts{$_})}for(qw(server directory ca_bundle)){if(defined $cfg{$_}){Licensebox::_arg($cfg{$_});$opts{$_}=$cfg{$_}}}
 bless {_native=>Licensebox::Native::_create($json->encode(\%opts),$hooks)},$class;
}
sub CLONE_SKIP {1}
sub close {my($self)=@_;if($self->{_native}){Licensebox::Native::_close($self->{_native});$self->{_native}=0}}
sub DESTROY {local $@;eval {$_[0]->close}}
sub _call {my($s,$op,$args)=@_;die bless({code=>'invalid_argument'},'Licensebox::Error') unless $s->{_native};$json->decode(Licensebox::Native::_call($s->{_native},$op,$json->encode($args||{})))}
sub lease {$_[0]->_call('lease')}
sub heartbeat {$_[0]->_call('heartbeat',{module=>do{Licensebox::_arg($_[1]);$_[1]}})}
sub require_module {$_[0]->_call('require',{module=>do{Licensebox::_arg($_[1]);$_[1]}})}
sub status {$_[0]->_call('status')}
sub sign_in {my($s,$timeout)=@_;$timeout//=0;die bless({code=>'invalid_argument'},'Licensebox::Error') unless isfinite($timeout);$s->_call('sign_in',{timeout=>$timeout})}
sub logout {$_[0]->_call('logout')}
sub modules {$_[0]->_call('modules')}
sub requests {$_[0]->_call('requests')}
sub request_access {my($s,$modules,$note)=@_;$note//='';Licensebox::_arg($note);Licensebox::_arg($_)for @$modules;$s->_call('request',{modules=>$modules,note=>$note})}
sub access_link {$_[0]->_call('access-link')}
sub record {my($s,$command,$success,$elapsed)=@_;Licensebox::_arg($command);die bless({code=>'invalid_argument'},'Licensebox::Error') unless isfinite($elapsed)&&$elapsed>=0;$s->_call('record',{command=>$command,success=>$success?JSON::PP::true:JSON::PP::false,elapsed=>$elapsed})}
1;
