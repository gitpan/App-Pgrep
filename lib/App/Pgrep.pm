package App::Pgrep;

use warnings;
use strict;

use base 'App::Pgrep::Base';
use App::Pgrep::Results;

use File::Next;
use PPI;    # we'll need to cache
use Scalar::Util 'reftype';

=head1 NAME

App::Pgrep - PPI-powered grep

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

my %HANDLER_FOR;

BEGIN {
    %HANDLER_FOR = (
        quote   => { stringify => sub { shift->string } },
        heredoc => {
            class     => 'Token::HereDoc',
            stringify => sub {
                
                # heredoc lines are terminated with newlines
                my @strings = shift->heredoc;
                return join '' => @strings;
            },
        },
        pod     => { 
            stringify => sub {
                
                # pod lines lines are *not* terminated with newlines
                my @strings = shift->lines;
                return join "\n" => @strings;
            },
        },
        comment => { stringify => sub { shift->content } }
    );
    foreach my $token ( keys %HANDLER_FOR ) {
        $HANDLER_FOR{$token}{class} ||= "Token::\u$token";

        # let them make it plural if they want
        $HANDLER_FOR{ $token . 's' }{class} = $HANDLER_FOR{$token}{class};
        $HANDLER_FOR{ $token . 's' }{stringify} =
          $HANDLER_FOR{$token}{stringify};
    }
}

=head1 SYNOPSIS

Use PPI to search through Perl documents.

    use App::Pgrep;

    my $pgrep = App::Pgrep->new( {
        dir      => $some_dir,
        look_for => [ 'pod', 'heredoc' ],
        pattern  => $some_regex,
    } );
    $pgrep->search;

=head1 DESCRIPTION

This is B<Alpha> code.  Probably has bugs and the output format of C<pgrep> is
likely to change at some point.  Also, we'll add more things you can search
for in the future.  Right now, you should just need to add them to the
C<%HANDLER_FOR> hash.

This software allows you to 'grep' through Perl documents.  Further, you can
specify which I<parts> of the documents you wish to search through.  While you
can use the class API directly, generally you'll use the C<pgrep> program
which is automatically installed.  For example, to search all comments for
'XXX' or 'xxx':

 pgrep --dir lib/ --pattern '(?i:XXX)' --search comments

See C<perldoc pgrep> for more examples of that interface.

See L<Allowed Tokens> for what you can search through.  This will be expanded
as time goes on.  Patches very welcome.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

    my $pgrep = App::Pgrep->new( {
        dir     => $some_dir,
        look_for => [ 'pod', 'heredoc' ],
    } );

The constructor takes a hashref of a rich variety of arguments.  This is
because the nature of what we're looking for can be quite complex.

The following keys are allowed (all are optional).

=over 4

=item * C<dir>

Specify the directory to search in.  Cannot be used with the C<files>
argument.

=item * C<files>

Specify an exact list of files to search in.  Cannot be used with the C<dir>
argument.

=item * C<look_for>

A scalar or array ref of the items (referred to as 'tokens') in Perl files to
look for.  If this key is omitted, default to:

 [ 'quote', 'heredoc' ]

See L<Allowed Tokens> for a list of which tokens you can search against.

=item * C<pattern>

Specify a pattern to search against.  This may be any valid Perl regular
expression.  Only results matching the pattern will be returned.

Will C<croak> if the pattern is not a valid regular expression.

=item * C<warnings>

By default, warnings are off.  Passing this a true value will enable warnings.
Currently, the only warning generated is when C<PPI> cannot parse the file.
This may be useful for debugging.

=item * C<filename_only>

By default, this value is false.  If passed a true value, only filenames whose
contents match the pattern for the tokens will be returned.

Note that This is optimized internally.  Once I<any> match is found, we stop
searching the document.  Thus, individual results are not available if
C<filename_only> is true.

=back

Additional keys may be added in the future.

=head3 C<Allowed Tokens>

The following token types are currently searchable:

=over 4

=item * C<quote>

Matches quoted strings (but not heredocs).

=item * C<heredoc>

Matches heredocs.

=item * C<pod>

Matches POD.

=item * C<comment>

Matches comments.

=back

Note that for convenience, you may specify a plural version of each token type
('heredocs' instead of 'heredoc').

=cut

sub _initialize {
    my ( $self, $arg_for ) = @_;

    $self->dir( delete $arg_for->{dir} );
    $self->files( delete $arg_for->{files} );
    $self->look_for( delete $arg_for->{look_for} );
    $self->pattern( delete $arg_for->{pattern} );
    $self->warnings( delete $arg_for->{warnings} );
    $self->filename_only( delete $arg_for->{filename_only} );
    unless ( @{ $self->look_for } ) {
        $self->look_for( [qw/ quote heredoc /] );
    }

    if ( my @keys = sort keys %$arg_for ) {
        local $" = ", ";
        $self->_croak("Unknown keys to new:  (@keys)");
    }
    if ( !$self->dir and !@{ $self->files } ) {
        $self->dir('.');
    }
    if ( $self->dir and @{ $self->files } ) {
        $self->_croak('You cannot specify both "dir" and "files"');
    }
    return $self;
}

=head3 C<handler_for>

 if ( App::Pgrep->handler_for('heredoc') ) {
    ...
 }

Returns a boolean value indicating whether or not a particular token type can
be handled.  Generally used internally..

=cut

sub handler_for {
    my ( $class, $token ) = @_;
    return $HANDLER_FOR{$token};
}

sub _class_for {
    my ( $class, $token_name ) = @_;
    if  ( my $class_for = $class->handler_for($token_name)->{class} ) {
        return $class_for;
    }
    $class->_croak("Cannot determine class for token ($token_name)");
}

sub _to_string {
    my ( $class, $token_name, $token ) = @_;
    if  ( my $to_string = $class->handler_for($token_name)->{stringify} ) {
        return $to_string->($token);
    }
    $class->_croak("Cannot determine to_string method for ($token_name)");
}

=head2 Instance Methods

=head3 C<dir>

 my $dir = $pgrep->dir;
 $pgrep->dir($dir);

Getter/setter for the directory to search in.

Will C<croak> if the directory cannot be found.

=cut

sub dir {
    my $self = shift;
    return $self->{dir} unless @_;
    my $dir = shift;
    if ( !defined $dir ) {
        $self->{dir} = undef;
        return $self;
    }
    unless ( -d $dir ) {
        $self->_croak("Cannot find directory ($dir)");
    }
    $self->{dir} = $dir;
    return $self;
}

=head3 C<files>

 my $files = $pgrep->files;   # array ref
 my @files = $pgrep->files;
 $pgrep->files(\@files);
 $pgrep->files($file);        # convenience

Getter/setter for files to search in.

Will C<croak> if any of the files cannot be found or read.

=cut

sub files {
    my $self = shift;
    unless (@_) {
        return wantarray ? @{ $self->{files} } : $self->{files};
    }
    my $files = shift;
    if ( !defined $files ) {
        $self->{files} = [];
        return $self;
    }

    $files = [$files] unless 'ARRAY' eq ( reftype $files || '' );
    foreach my $file (@$files) {
        unless ( -e $file && -r _ ) {
            $self->_croak("Cannot find or read file ($file)");
        }
    }
    $self->{files} = $files;
}

=head3 C<look_for>

 my $look_for = $pgrep->look_for;   # array ref
 my @look_for = $pgrep->look_for;
 $pgrep->look_for( [qw/ pod heredoc /] );
 $pgrep->look_for('pod');        # convenience

Getter/setter for the token types to search.

Will C<croak> if any of the token types cannot be found.

=cut

sub look_for {
    my $self = shift;
    unless (@_) {
        return wantarray ? @{ $self->{look_for} } : $self->{look_for};
    }
    my $look_for = shift;
    if ( !defined $look_for ) {
        $self->{look_for} = [];
        return $self;
    }

    $look_for = [$look_for] unless 'ARRAY' eq ( reftype $look_for || '' );
    foreach my $look_for (@$look_for) {
        unless ( $self->handler_for($look_for) ) {
            $self->_croak("Don't know how to look_for ($look_for)");
        }
    }
    $self->{look_for} = $look_for;
}

=head3 C<pattern>

 my $pattern = $pgrep->pattern;
 $pgrep->pattern($patten);

Getter/setter for the pattern to search for.  Defaults to the empty string.
The pattern must be a valid Perl regular expression.

Will C<croak> if if supplied with an invalid pattern.

=cut

sub pattern {
    my $self = shift;
    return $self->{pattern} unless @_;
    my $test_pattern = shift;
    $test_pattern ||= '';
    my $pattern = eval { qr/$test_pattern/ };
    if ( my $error = $@ ) {
        $self->_croak("Could not search on ($test_pattern):  $error");
    }
    $self->{pattern} = $pattern;
    return $self;
}

=head3 C<warnings>

 if ( $pgrep->warnings ) {
      warn $some_message;
 }
 $pgrep->warnings(0);   # turn warnings off
 $pgrep->warnings(1);   # turn warnings on

Turn warnings on or off.  By defalt, warnings are off.

=cut

sub warnings {
    my $self = shift;
    return $self->{warnings} unless @_;
    $self->{warnings} = shift;
    return $self;
}

=head3 C<filename_only>

 if ( $pgrep->filename_only ) { ... }
 $pgrep->filename_only(1);

Boolean getter/setter for whether to only report matching filenames.  If true,
result objects returned from C<search> will only report a matching filename
and attempting to fetch results from the will C<croak>.

=cut

sub filename_only {
    my $self = shift;
    return $self->{filename_only} unless @_;
    $self->{filename_only} = shift;
}

=head3 C<search>

 $pgrep->search;

This method searches the chosen directories or files for the chosen
C<pattern>.  Only tokens listed in C<look_for> will be searched.

If called in void context, will print the results, if any to C<STDOUT>.  If
C<filename_only> is true, will only print the filenames of matching files.

If results are found, returns a list or array reference (depending upon
whether it's called in list or scalar context) of C<App::Pgrep::Results>
objects.  If you prefer to use the C<App::Pgrep> API instead of the C<pgrep>
program, you can process the results as follows:

 my @results = $pgrep->search;
 foreach my $found (@results) {
     print $found->file, "\n";
     while ( my $result = $found->next ) {
         print $result->token, "matched:\n";
         while ( my $item = $result->next ) {
             print "\t$item\n";
         }
     }
 }

=cut

sub search {
    my $self = shift;
    my $files = $self->_file_iterator;
    my @search;
    if ( !defined wantarray ) {

        # called in void context so they want results sent to C<STDOUT>.
        require Data::Dumper;
        $Data::Dumper::Terse = 1;
    }
    while ( defined ( my $file = $files->() ) ) {
        my $found = $self->_search_for_tokens_in($file);
        next unless $found;
        if ( !defined wantarray ) {
            $self->_print_results($found);
        }
        else {
            push @search => $found;
        }
    }
    return wantarray ? @search : \@search;
}

sub _print_results {
    my ( $self, $found ) = @_;
    print $found->file."\n";
    next if $self->filename_only;

    while ( my $result = $found->next ) {
        print "  '". $result->token, "' matched:\n";
        while ( my $item = $result->next ) {
            $item =~ s/\n/\n    /g;
            print "    ".Data::Dumper::Dumper($item);
        }
    }
    return $self;
}

sub _search_for_tokens_in {
    my ( $self, $file ) = @_;
    my $pattern = $self->pattern;
    my $doc = PPI::Document->new( $file, readonly => 1 );
    unless ($doc) {
        $self->_warn("Cannot create a PPI document for ($file).  Skipping.");
        return;
    }
    my $found = App::Pgrep::Results->new( { file => $file } );
    $found->filename_only( $self->filename_only );
    foreach my $token ( $self->look_for ) {
        my $class     = $self->_class_for($token);
        my @found = @{ $doc->find($class) || [] };
        my @results;
        foreach my $result (@found) {
            $result = $self->_to_string( $token, $result );
            next unless $result =~ $pattern;

            # a tiny optimization
            if ( $self->filename_only ) {
                return $found;
            }
            push @results => $result;
        }
        $found->add_results( $token => \@results ) if @results;
    }
    return unless $found->have_results; 
    return $found;
}

sub _file_iterator {
    my $self = shift;
    if ( my $dir = $self->dir ) {
        return File::Next::files($dir);
    }
    elsif ( my $files = $self->files ) {
        return sub { shift @$files };
    }
    $self->_croak("No files or directories to search in!");
}

sub _warn {
    my ( $self, $message ) = @_;
    return unless $self->warnings;
    warn "$message\n";
}

=head1 AUTHOR

Curtis Poe, C<< <ovid at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-app-pgrep at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Pgrep>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=over 4

=item * Currently line numbers are not available.

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Pgrep

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Pgrep>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Pgrep>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Pgrep>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Pgrep>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Curtis Poe, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of App::Pgrep
