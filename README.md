[![Build Status](https://travis-ci.org/dmanto/Mojo-Chrome.svg?branch=master)](https://travis-ci.org/dmanto/Mojo-Chrome) [![Build Status](https://img.shields.io/appveyor/ci/dmanto/Mojo-Chrome/master.svg?logo=appveyor)](https://ci.appveyor.com/project/dmanto/Mojo-Chrome/branch/master)
# NAME

Mojo-Chrome - A Mojo interface to Chrome DevTools Protocol

# SYNOPSIS

    # This is the example from https://medium.com/@lagenar/using-headless-chrome-via-the-websockets-interface-5f498fb67e0f
    # of fetching the news headline from Google News. It should not be used as anything but an example.
    # It is archived at https://web.archive.org/web/20171020022803/https://medium.com/@lagenar/using-headless-chrome-via-the-websockets-interface-5f498fb67e0f

    use Mojo::Base -strict;

    use Mojo::Chrome;
    use Mojo::IOLoop;

    binmode(STDOUT, ":utf8");
    $|++;

    my $chrome = Mojo::Chrome->new->catch(sub{ warn pop });
    my $url = 'https://news.google.com/news/?ned=us&hl=en';

    Mojo::IOLoop->delay(
      sub { $chrome->load_page($url, shift->begin) },
      sub {
        my ($delay, $err) = @_;
        die $err if $err;
        $chrome->evaluate(<<'    JS', $delay->begin);
          var sel = '[role="heading"][aria-level="2"]';
          var headings = document.querySelectorAll(sel);
          [].slice.call(headings).map((link)=>{return link.innerText});
        JS
      },
      sub {
        my ($delay, $err, $result) = @_;
        die Mojo::Util::dumper $err if $err;
        say for @$result;
      }
    )->catch(sub{ warn pop })->wait;

# DESCRIPTION

[Mojo::Chrome](https://metacpan.org/pod/Mojo::Chrome) is an interface to the Chrome DevTools Protocol which allows interaction with a (possibly headless) chrome instance.
While [Mojo::Chrome](https://metacpan.org/pod/Mojo::Chrome) is primarily intended as a backbone for [Test::Mojo::Role::Chrome](https://metacpan.org/pod/Test::Mojo::Role::Chrome), this is not its only purpose.

Communication is bidirectional and asynchronous via an internal websocket.
Both request/response and push-events are commonplace, though this module does its best to simplify things.

This module is the spiritual successor to [Mojo::Phantom](https://metacpan.org/pod/Mojo::Phantom) which interfaced with the headless phantomjs application.
That project was abandoned after the headless chrome functionality was announced.

[Mojo::Phantom](https://metacpan.org/pod/Mojo::Phantom) had many short-cuts that were intended to smooth out the experience since communication was essentially unidirectional after the page load and the process or at least the page state was ephemeral.
Because of the robust communication afforded by the Chrome DevTools Protocol many of those short-cuts will not be replicated for `Mojo::Chome`.
However with the increased power the author suspects that new short-cuts will be desirable, suggestions are welcome.

# CAVEATS

**WARNING:** Until released to CPAN this module is considered pre-alpha and absolutely no support or stability is promised.
Not even what follows in this section of the documentation, which will only apply upon the first CPAN release.

This module is new and changes may occur.
High level functionality should be fairly stable.

The protocol itself is fairly new and largely undocumented, especially in usage documentation.
If this module skews from the protocol in newer versions of chrome please alert the author via the bug tracker.
Incompatibilites can hopefully be smoothed out in the module however where this isn't possible the author intends to target newer versions of chrome rather than support a long tail of chrome version.

Errors are basically the wild west.
While methods should have error slots where errors should arrive, whether they do or not is up in the air.
This is especially true of errors that eminate from within the protocol itself.
Certainly this will need to be improved but it is difficult with the protocol documentation in its current state.
Pull requests and other constructive comments are always welcome.

# CONNECTING AND SPAWNING

This module attempts to connect and/or reconnect to Chrome's DevTools Protocol and even spawn an instance of Chrome so as to make that as seemless as possible to the user.
Any method that sends a command will first check for a connection and if it doesn't exist attempt to create one.
Further if a connection can't be made or if a port to connect on hasn't been specified it will spawn a new instance.
In the case that no port was specified a random free port will be used.
(Note that an additional randomly selected free port is used during startup and is then dropped once the startup is complete.)

All this should be as transparent and "do what I mean" as possible.

# EVENTS

[Mojo::Chrome](https://metacpan.org/pod/Mojo::Chrome) inherits all of the events from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo::EventEmitter).
Further it emits events that arrive from the protocol as they arrive.
Per the protocol most events are disabled initially, though some methods will enable and subscribe to events as a matter of course.

Eventually this documentation might suggest best practices or contain other functionality to moderate events.
For the time being simply consider that fact, especially when disabling protocol events.

# ATTRIBUTES

[Mojo::Chrome](https://metacpan.org/pod/Mojo::Chrome) inherits all of the attributes from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo::EventEmitter) and implements the following new ones.

## arguments

An array reference of command line arguments passed to the ["executable"](#executable) if a chrome process is spawned.
Therefore the default contains only `--headless`.
A useful option to consider is `--disable-gpu` which is not enabled by default.
Note that `--remote_debugging_port` should not be given, use the ["target"](#target)'s port value instead.

## base

A base url used to make relative urls absolute.
Must be an instance of [Mojo::URL](https://metacpan.org/pod/Mojo::URL) or api compatible class.

## executable

The name of the chrome executable (if it is in the `$PATH`) or an absolute path to the chrome executable.
Default is to use ["detect\_chrome\_executable"](#detect_chrome_executable) to discover it.
If unset and not detectable, throws an exception when used.

## tx

The [Mojo::Transaction](https://metacpan.org/pod/Mojo::Transaction) object maintaining the websocket connection to chrome.

## ua

The [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) object used to open the connection to chrome if necessary.

## target

An instance of [Mojo::URL](https://metacpan.org/pod/Mojo::URL) (or api compatible class) used to contact a running process of chrome.
If one is not specified a new chrome process will be spawned on a random port.
If the port is specifed but cannot be contacted then a new chrome process will be spawned using that port.
Default is `http://127.0.0.1`.

# CLASS METHODS

## detect\_chrome\_executable

    my $path = Mojo::Chrome->detect_chrome_executable;

Returns the path of the chrome executable to be used.
The following heuristic is used:

- If the environment variable `MOJO_CHROME_EXECUTABLE` is set that is immediately returned, no check is performed.
- If an executable file named `google-chrome` exists in your PATH (as determined by ["can\_run" in IPC::Cmd](https://metacpan.org/pod/IPC::Cmd#can_run)) and is executable, then that path is returned.
- If the system is `darwin` (i.e. Mac), then if `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` exists and is executable, then that path is returned.
- Otherwise returns `undef`.

# METHODS

[Mojo::Chrome](https://metacpan.org/pod/Mojo::Chrome) inherits all of the methods from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo::EventEmitter) and implements the following new ones.

## evaluate

    $chrome->evaluate('JS', sub { my ($chrome, $error, $value) = @_; ... });
      Array.from(document.getElementsByTagName('p')).map(e => e.innerText);
    JS

Evaluate a javascript snippet and return the result of the last statement.
If passed a hash reference this is assumed to be arguments passed to DevTools' [Runtime.evaluate](https://chromedevtools.github.io/devtools-protocol/tot/Runtime/#method-evaluate).
Otherwise the value is assumed to be the expression (and the `returnByValue` option will be set to true).
The callback will receive the invocant, any error, then the value of the last evaluated statement.

Note that other complex behaviors are possible when explicitly passing your own arguments, so please investigate those if this behavior seems limiting.

## from\_url

    my $chrome = Mojo::Chrome->new->from_url($url);

A shortcut to use a string or [Mojo::URL](https://metacpan.org/pod/Mojo::URL) to set the arguments for this class (see also ["new"](#new)).

The scheme, host, and port portions set the ["target"](#target) indicating where to connect to chrome's DevTools Protocol.

Query parameters are available to control the spawned chrome process.
If given, the `executable` parameter is used to set the ["executable"](#executable) otherwise the default is not changed.

All other parameters are interpreted as command line switches and used to set the ["arguments"](#arguments).
The parameter `headless` is considered a default and is appended unless the parameter `headless` or `no-headless` is explicitly given.
Note that `no-headless` is not an official parameter but is added here to prevent the default of adding `headless`.
`remote_debugging_port` should not be given, pass as the port part of the url instead.

## load\_page

    $chrome->load_page($url, sub { my ($chrome, $error) = @_; ... });

Request a page and load the result, evaluating any initial javascript in the process.
This subscribes to [Page](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-enable) events and then requests the page with [Page.navigate](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-navigate).
It then invokes the callback when the appropriate [Page.frameStoppedLoading](https://chromedevtools.github.io/devtools-protocol/tot/Page/#event-frameStoppedLoading) event is caught.

If passed a hash reference this is assumed to the the arguments passed to the `Page.navigate` method.
Otherwise the value is assumed to the be url to load.
If the url (given either way) is relative, it will be made absolute using the ["base"](#base) url.

## new

    my $chrome = Mojo::Chrome->new(%attributes);
    my $chrome = Mojo::Chrome->new(\%attributes);
    my $chrome = Mojo::Chrome->new($url);

Construct a new instance of [Mojo::Chrome](https://metacpan.org/pod/Mojo::Chrome).
If given a single arugment which is not a hash reference that argument is passed to ["from\_url"](#from_url) to create an instance from a url.
Otherwise the usual ["new" in Mojo::Base](https://metacpan.org/pod/Mojo::Base#new) behavior is followed.

## send\_command

    $chrome->send_command($method, $params, sub { my ($chrome, $error, $result) = @_; ... });

A lower level method to send a command via the protocol.
The arguments are a method and a hash reference of parameters.
If given, a callback will be invoked when a response is received (N.B. issuing ids and watching for responses is handled transparently internally).
The callback is passed the invocant, any error, and the result.

This method lets you interact with the protocol and while it does simplify some of that process it is still quite low level.

# PROTOCOL DOCUMENTATION

- [https://chromedevtools.github.io/devtools-protocol](https://chromedevtools.github.io/devtools-protocol)
- [https://developers.google.com/web/updates/2017/04/headless-chrome](https://developers.google.com/web/updates/2017/04/headless-chrome)

# SEE ALSO

- [Test::Mojo::Role::Chrome](https://metacpan.org/pod/Test::Mojo::Role::Chrome)
- [Mojolicious](https://metacpan.org/pod/Mojolicious)

# SOURCE REPOSITORY

[http://github.com/jberger/Mojo-Chrome](http://github.com/jberger/Mojo-Chrome)

# AUTHOR

Joel Berger, <joel.a.berger@gmail.com>

# CONTRIBUTORS

# COPYRIGHT AND LICENSE

Copyright (C) 2017 by ["AUTHOR"](#author) and ["CONTRIBUTORS"](#contributors).
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
