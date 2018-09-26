requires 'perl' => '5.10.0';
requires 'Mojolicious', '8.01'; # -role
requires 'IPC::Cmd';
requires 'Role::Tiny';
requires 'Test::Simple', '1.302015'; # Test2
requires 'Mojolicious::Plugin::AutoReload'; # chat example

configure_requires 'IPC::Cmd';
configure_requires 'Module::Build::Tiny';

author_requires 'App::ModuleBuildTiny';
author_requires 'Module::Metadata', '1.000009';
