package Data::All::Base;

#   A base Spiffy module for all of Data::All

use strict;
no warnings;            #   Perl will complain about attribute being redefined


use Symbol;
use Spiffy '-base';
use Data::Dumper;
#use Log::Log4perl;

our $VERSION = 1.0;
our @EXPORT = qw(new internal attribute populate Dumper error);

sub internal;
internal 'ERROR';

sub error
{
    my ($self) = @_;
    
    return $self->__ERROR();
}

sub new
#   Bypass Spiffy's new, so we can call init()
{
    my $class = shift;
    
    my $self = bless Symbol::gensym(), $class;
    my ($args) = $self->parse_arguments(@_);
    tie *$self, $self if $args->{-tie};
    $self->use_lock(1) if $args->{-lock};

    return ($self->can('init'))
        ? $self->init(@_)
        : $self;
}



sub populate 
#   populate $self->ACCESSOR with arguments in $args.
#   This is usually called by init() after the args have been parsed. 
{
    my ($self, $args) = @_;

    for my $a (keys %{ $args })
    {
        warn("No attribute method for $a"), next 
            unless $self->can($a);
        #warn 9, "Running $a"; 
        $self->$a($args->{$a});
    }
}

sub attribute 
#   See Spiffy or better yet, IO::All where this code came from
{
    my $package = caller;
    my ($attribute, $default) = @_;
    no strict 'refs';
    return if defined &{"${package}::$attribute"};
    *{"${package}::$attribute"} =
      sub {
          my $self = shift;
          unless (exists *$self->{$attribute}) {
              *$self->{$attribute} = 
                ref($default) eq 'ARRAY' ? [] :
                ref($default) eq 'HASH' ? {} : 
                $default;
          }
          return *$self->{$attribute} unless @_;
          *$self->{$attribute} = shift;
      };
}

sub internal
#   Used like attribute 'name' => 'val'. The difference being
#   the internal attribute and it accessor are stored as '__name'
{
    my $package = caller;
    my ($attribute, $default) = @_;
    $attribute = "__$attribute";
    no strict 'refs';
    return if defined &{"${package}::$attribute"};
    *{"${package}::$attribute"} =
      sub {
          my $self = shift;
          unless (exists *$self->{$attribute}) {
              *$self->{$attribute} = $default;
          }
          return *$self->{$attribute} unless @_;
          *$self->{$attribute} = shift;
      };
}



1;