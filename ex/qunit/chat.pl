use Mojolicious::Lite;
use Mojo::EventEmitter;

plugin AutoReload => {};

helper events => sub { state $events = Mojo::EventEmitter->new };

get '/'              => 'chat';
get '/tests'         => 'tests';
websocket '/channel' => sub {
  my $c = shift;

  $c->inactivity_timeout(3600);

  # Forward messages from the browser
  $c->on(message => sub { shift->events->emit(mojochat => shift) });

  # Forward messages to the browser
  my $cb = $c->events->on(mojochat => sub { $c->send(pop) });
  $c->on(finish => sub { shift->events->unsubscribe(mojochat => $cb) });
};

# Minimal single-process WebSocket chat application for browser testing
app->start;
__DATA__
@@ chat.html.ep
<form onsubmit="sendChat(this.children[0]); return false"><input></form>
<div id="log"></div>
<script>
  var ws  = new WebSocket('<%= url_for('channel')->to_abs %>');
  ws.onmessage = function (e) {
    document.getElementById('log').innerHTML += '<p>' + e.data + '</p>';
  };
  function sendChat(input) { ws.send(input.value); input.value = '' }
</script>

@@ tests.html.ep
%= auto_reload;
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width">
  <title>QUnit Tests</title>
  <link rel="stylesheet" href="https://code.jquery.com/qunit/qunit-2.6.2.css">
</head>
<body>
  <div id="qunit"></div>
  <div id="qunit-fixture"></div>
  <script src="https://code.jquery.com/qunit/qunit-2.6.2.js"></script>
  <iframe id="f1" src="/" height="240" width="320"></iframe>
  <iframe id="f2" src="/" height="240" width="320"></iframe>
  <script src="tests.js?t=<%= time %>"></script>
</body>
</html>

@@ tests.js
var c1 = document.getElementById('f1').contentWindow;
var c2 = document.getElementById('f2').contentWindow;
QUnit.test( "hello test", function( assert ) {
  assert.ok( 1 == "1", "Passed!" );
});
QUnit.test( "Wait for websockets ready", function( assert ) {
  assert.timeout(1000);
  var done = assert.async();
  var intvl = setInterval(function() {
    if (
      c1.ws && c1.ws.readyState == 1 &&
      c2.ws && c2.ws.readyState == 1
      ) { // OPEN
      clearInterval(intvl);
      assert.ok(true, "ws for both frames connected");
      // now we can chat a couple of messages
      c1.document.querySelector('form input').value = 'Message #1';
      c2.document.querySelector('form input').value = 'Message #2';
      c1.document.querySelector('form').dispatchEvent(new Event('submit'));
      c2.document.querySelector('form').dispatchEvent(new Event('submit'));
      done();
    }
  }, 5);
});
QUnit.test( "Wait for messages in log", function( assert ) {
  assert.timeout(1000);
  var done = assert.async();
  var intvl = setInterval(function() {
    if (
      c1.document.getElementById('log').innerHTML.match(/Message #1/) && 
      c1.document.getElementById('log').innerHTML.match(/Message #2/) && 
      c2.document.getElementById('log').innerHTML.match(/Message #1/) && 
      c2.document.getElementById('log').innerHTML.match(/Message #2/)
      ) {
      clearInterval(intvl);
      assert.ok(true, "log messages for both frames completed");
      done();
    }
  }, 5);
});
