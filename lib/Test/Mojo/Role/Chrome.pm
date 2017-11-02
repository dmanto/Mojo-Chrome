package Test::Mojo::Role::Chrome;

use Role::Tiny;
use Mojo::Base -strict;
use Mojo::Chrome;
use Mojo::Util;
use Test2::API ();
use Test::More ();

__PACKAGE__->Mojo::Base::attr(chrome => sub {
  Mojo::Chrome->new(base => shift->ua->server->nb_url);
});
__PACKAGE__->Mojo::Base::attr('chrome_result');

my $_desc = sub { Mojo::Util::encode 'UTF-8', shift || shift };

sub chrome_load_ok {
  my ($self, $navigate, $desc) = @_;
  $desc = $_desc->($desc, 'Chrome navigate to page');
  my $ctx = Test2::API::context();

  my $ok = 0;
  my $err;
  $self->chrome->load_page($navigate, sub {
    (undef, $err) = @_;
    $ok = 1 unless $err;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $ctx->diag($err) if $err;
  $ctx->ok($ok, $desc);
  $ctx->release;
  return $self->success($ok);
}

sub chrome_evaluate_ok {
  my ($self, $js, $desc) = @_;
  $desc = $_desc->($desc, 'Chrome evaluate');
  my $ctx = Test2::API::context();

  my $ok = 0;
  my ($err, $result);
  $self->chrome->evaluate($js, sub {
    (undef, $err, $result) = @_;
    $ok = 1 unless $err;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $ctx->diag(Mojo::Util::dumper $err) if $err;
  $ctx->ok($ok, $desc);
  $ctx->release;
  return $self->chrome_result($result)->success($ok);
}

sub chrome_result_is {
  my $self = shift;
  my ($p, $expect) = @_ > 1 ? (shift, shift) : ('', shift);
  my $desc = $_desc->(shift, qq{exact match for JSON Pointer "$p"});
  my $data = Mojo::JSON::Pointer->new($self->chrome_result)->get($p);

  my $ctx = Test2::API::context();
  $self->success(Test::More::is_deeply($data, $expect, $desc));
  $ctx->release;
  $self;
}


1;

=head1 NAME

Test::Mojo::Role::Chrome - Chrome for your testing

=head1 SYNOPSIS


  use Mojolicious::Lite;

  use Test::More;

  any '/' => 'index';

  my $t = Test::Mojo->with_roles('+Chrome')->new;

  $t->chrome_load_ok('/')
    ->chrome_evaluate_ok(q[document.getElementById('name').innerHTML])
    ->chrome_result_is('Bender');

  done_testing;

  __DATA__

  @@ index.html.ep

  <!DOCTYPE html>
  <html>
    <head></head>
    <body>
      <p id="name">Leela</p>
      <script>
        (function(){ document.getElementById('name').innerHTML = 'Bender' })();
      </script>
    </body>
  </html>

=head1 DESCRIPTION

L<Test::Mojo::Role::Phantom> adds the ability to test front-end behavior to your L<Test::Mojo> instance.
It uses L<Mojo::Chrome> to interface to the Chrome DevTools Protocol as its backbone.

This module is the spiritual successor to L<Test::Mojo::Role::Phantom> which interfaced with the headless phantomjs application.
That project was abandoned after the headless chrome functionality was announced.

L<Test::Mojo::Role::Phantom> and L<Mojo::Phantom> had many short-cuts that were intended to smooth out the experience since communication was essentially unidirectional after the page load and the process or at least the page state was ephemeral.
Because of the robust communication afforded by the Chrome DevTools Protocol many of those short-cuts will not be replicated for C<Test::Mojo::Role::Chome>.
However with the increased power the author suspects that new short-cuts will be desirable, suggestions are welcome.

As this module is new as is the protocol, please familiarize yourself with the L<Mojo::Chrome/Caveats> before using.


