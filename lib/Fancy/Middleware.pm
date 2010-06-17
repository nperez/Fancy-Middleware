package Fancy::Middleware;
use MooseX::Declare;

#ABSTRACT: Provides alternate implementation of Plack::Middleware in a Moose Role

=head1 SYNOPSIS

    use MooseX::Declare;
    
    class My::Custom::Middleware::Logger
    {
        with 'Fancy::Middleware';

        has logger =>
        (
            is => 'ro',
            isa => 'SomeLoggerClass',
            required => 1,
        );

        around preinvoke()
        {
            $self->env->{'my.custom.middleware.logger'} = $self->logger;
        }
    }

    ...

    my $app = My::Web::Simple::Subclass->as_psgi_app();
    $app = My::Custom::Middleware::Logger->wrap($app, logger => $some_logger_instance);

=cut


=head1 DESCRIPTION

Fancy::Middleware is an alternate implementation of the Plack::Middleware base
class but as a Moose Role instead. This gives us a bit more flexibility in how 
how the Middleware functionality is gained in a class without having to
explicitly subclass. That said, this Role should fit in just fine with other
Plack::Middleware implemented solutions as the API is similar.

There are some differences that should be noted.

Three distinct "phases" were realized: L</preinvoke>, L</invoke>,
L</postinvoke>. This allows more fine grained control on where in the process
middleware customizations should take place.

Also, more validation is in place than provided by Plack::Middleware. The
response is checked against L<POEx::Types::PSGIServer/PSGIResponse>, the
L</env> hash is constrained to HashRef, and L</app> is constrained to a
CodeRef.

=cut

role Fancy::Middleware
{
    use POEx::Types::PSGIServer(':all');
    use MooseX::Types::Moose(':all');

=attribute_public app

    is: ro, isa: CodeRef, required: 1

app is the actual PSGI application. 

=cut

    has app => (is => 'ro', isa => CodeRef, required => 1);

=attribute_public response

    is: ro, isa: PSGIResponse, writer: set_response

response holds the result from the invocation of the PSGI application. This is
useful if the response needs to be filtered after invocation. 

=cut

    has response => (is => 'ro', isa => PSGIResponse, writer => 'set_response');

=attribute_public env

    is: ro, isa: HashRef, writer: set_env

env has the environment hash passed from the server during L</call>.

=cut
    
    has env => (is => 'ro', isa => HashRef, writer => 'set_env');

=class_method wrap

    (ClassName $class: CodeRef $app, @args)

wrap is defined by Plack::Middleware as a method that takes a PSGI application
coderef and wraps is with the middleware, returning the now wrapped coderef.

Internally, this means the class itself is instantiated with the provided
arguments with $app being passed to the constructor as well. Then to_app is
called and the result returned.

=cut

    method wrap(ClassName $class: CodeRef $app, @args)
    {
        my $self = $class->new(app => $app, @args);
        return $self->to_app;
    }

=method_public call

    (HashRef $env)

call is also defined by Plack::Middleware as the method to implement to perform
work upon the provided application with the supplied $env hash. Instead of 
overriding this method, move your implementation pieces into one of the methods
below.

=cut

    method call(HashRef $env)
    {
        $self->set_env($env);
        $self->preinvoke();
        $self->invoke();
        $self->postinvoke();
        return $self->response;
    }

=method_public preinvoke

preinvoke is called prior to L</invoke>. By default it simply returns. Exclude
or advise this method to provide any work that should take place prior to
actually invoking the application. Note, that there isn't a valid PSGIResponse
at this point. 

=cut

    method preinvoke()
    {
        return;
    }

=method_public invoke

invoke executes L</app> with L</env> provided as the argument. The result is
stored in L</response>. If application execution should be short circuited for
any reason, this would be the place to do it.

=cut

    method invoke()
    {
        $self->set_response(($self->app)->($self->env));
    }

=method_public postinvoke

postinvoke is called after invoke returns. If the L</response> needs filtering
applied to it, this is the place to do it.

=cut

    method postinvoke()
    {
        return;
    }

=method_public to_app

to_app returns a coderef that closes around $self. When executed, it calls
L</call> with all of the arguments presented to it. 

=cut

    method to_app()
    {   
        return sub { $self->call(@_) };
    }
}

1;
__END__

