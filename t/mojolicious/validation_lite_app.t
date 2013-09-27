use Mojo::Base -strict;

BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

get '/' => sub {
  my $self       = shift;
  my $validation = $self->validation;
  return $self->render unless $validation->is_submitted;
  $validation->required('foo')->size(2, 5);
  $validation->optional('bar')->size(2, 5);
  $validation->optional('baz')->size(2, 5);
} => 'index';

my $t = Test::Mojo->new;

# Required and optional values
my $validation = $t->app->validation;
$validation->input({foo => 'bar', baz => 'yada'});
ok $validation->required('foo')->is_valid, 'valid';
is_deeply $validation->output, {foo => 'bar'}, 'right result';
is $validation->param('foo'), 'bar', 'right value';
is_deeply [$validation->param], ['foo'], 'right names';
ok !$validation->has_errors, 'no errors';
ok $validation->optional('baz')->is_valid, 'valid';
is_deeply $validation->output, {foo => 'bar', baz => 'yada'}, 'right result';
is $validation->param('baz'), 'yada', 'right value';
is_deeply [$validation->param], [qw(baz foo)], 'right names';
is_deeply [$validation->param([qw(foo baz)])], [qw(bar yada)], 'right values';
ok !$validation->has_errors, 'no errors';
ok !$validation->optional('does_not_exist')->is_valid, 'not valid';
is_deeply $validation->output, {foo => 'bar', baz => 'yada'}, 'right result';
ok !$validation->has_errors, 'no errors';
ok !$validation->required('does_not_exist')->is_valid, 'not valid';
is_deeply $validation->output, {foo => 'bar', baz => 'yada'}, 'right result';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('does_not_exist')->each],
  ['Value is required.'], 'right error';

# Size
$validation = $t->app->validation;
$validation->input({foo => 'bar', baz => 'yada', yada => 'yada'});
ok $validation->required('foo')->size(1, 3)->is_valid, 'valid';
is_deeply $validation->output, {foo => 'bar'}, 'right result';
ok !$validation->has_errors, 'no errors';
ok !$validation->required('baz')->size(1, 3)->is_valid, 'not valid';
is_deeply $validation->output, {foo => 'bar'}, 'right result';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('baz')->each],
  ['Value needs to be 1-3 characters long.'], 'right error';
ok !$validation->required('yada')->size(5, 10)->is_valid, 'not valid';
is_deeply $validation->output, {foo => 'bar'}, 'right result';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('yada')->each],
  ['Value needs to be 5-10 characters long.'], 'right error';

# Custom errors
$validation = $t->app->validation;
ok !$validation->has_errors('bar'), 'no errors';
$validation->input({foo => 'bar', yada => 'yada'});
ok !$validation->error('Bar is required.')->required('bar')->is_valid,
  'not valid';
is_deeply $validation->output, {}, 'right result';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('bar')->each], ['Bar is required.'],
  'right error';
ok !$validation->required('baz')->is_valid, 'not valid';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('baz')->each], ['Value is required.'],
  'right error';
ok !$validation->required('foo')->error('Foo is too small.')->size(25, 100)
  ->is_valid, 'not valid';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('foo')->each], ['Foo is too small.'],
  'right error';
is $validation->topic, 'foo', 'right topic';
ok !$validation->error('Failed!')->required('yada')->size(25, 100)->is_valid,
  'not valid';
ok $validation->has_errors, 'has errors';
is_deeply [$validation->errors('yada')->each],
  ['Value needs to be 25-100 characters long.'], 'right error';
is $validation->topic, 'yada', 'right topic';
ok $validation->has_errors('bar'), 'has errors';

# No validation
$t->get_ok('/')->status_is(200)->element_exists('form > input')
  ->element_exists('form > textarea')->element_exists('form > select');

# Successful validation
$t->get_ok('/?foo=ok')->status_is(200)->element_exists('form > input')
  ->element_exists('form > textarea')->element_exists('form > select');

# Failed validation
$t->get_ok('/?foo=too_long&bar=too_long_too&baz=way_too_long')->status_is(200)
  ->element_exists_not('form > input')
  ->element_exists('form > div.fields_with_errors > input')
  ->element_exists_not('form > textarea')
  ->element_exists('form > div.fields_with_errors > textarea')
  ->element_exists_not('form > select')
  ->element_exists('form > div.fields_with_errors > select');

done_testing();

__DATA__

@@ index.html.ep
%= form_for index => begin
  %= text_field 'foo'
  %= text_area 'bar'
  %= select_field baz => [qw(yada yada)]
% end