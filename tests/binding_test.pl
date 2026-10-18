use strict;use warnings;use Test::More;use Licensebox;use File::Temp qw(tempdir);
like Licensebox::derive_binding('demo','linux-machine-id',"12345678123456789abc1234567890ab\0"),qr/^m1:/;
eval{Licensebox::verify_lease('bad','demo',{},0)};is $@->code,'malformed';
my $dir=tempdir(CLEANUP=>1);
my $c=Licensebox::Client->new(product=>'demo',keys=>{'test-key'=>'A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg'},directory=>$dir,hooks=>{machine_binding=>sub{die 'synthetic callback failure'}});
eval{$c->sign_in(.1)};is $@->code,'callback_error';$c->close;$c->close;
done_testing;
