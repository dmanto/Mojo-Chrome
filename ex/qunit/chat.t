use Test::More;
use Test::Mojo;
use Mojo::File qw/path/;
use FindBin;

my $t = Test::Mojo->with_roles('+Chrome')->new(path("$FindBin::Bin/chat.pl"));

$t->chrome_load_ok('/tests')->chrome_wait_for_text_is(
  'title',
  "\x{2714} QUnit Tests",
  'Espera fin QUnit'
  )

  # ->chrome_evaluate_ok(q!document.querySelector('title').innerText!)
  ->chrome_result_is("\x{2714} QUnit Tests");

done_testing;
