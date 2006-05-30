# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::Config::GeneBuild::Targetted - imports global variables used by EnsEMBL gene building

=head1 SYNOPSIS
    use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Targetted;
    use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Targetted qw(  );

=head1 DESCRIPTION

Targetted is a pure ripoff of humConf written by James Gilbert.

humConf is based upon ideas from the standard perl Env environment
module.

It imports and sets a number of standard global variables into the
calling package, which are used in many scripts in the human sequence
analysis system.  The variables are first decalared using "use vars",
so that it can be used when "use strict" is in use in the calling
script.  Without arguments all the standard variables are set, and
with a list, only those variables whose names are provided are set.
The module will die if a variable which doesn\'t appear in its
C<%Targetted> hash is asked to be set.

The variables can also be references to arrays or hashes.

Edit C<%Targetted> to add or alter variables.

All the variables are in capitals, so that they resemble environment
variables.

=head1 CONTACT

=cut


package Bio::EnsEMBL::Pipeline::Config::GeneBuild::Targetted;

use strict;
use vars qw( %Targetted );

# Hash containing config info
%Targetted = (
	      
	      # minimum required coverage for multiexon predictions
	      GB_TARGETTED_MULTI_EXON_COVERAGE      => '25',

	      # minimum required coverage for single predictions
	      GB_TARGETTED_SINGLE_EXON_COVERAGE     => '80',

	      # maximum allowed size of intron in Targetted gene
	      GB_TARGETTED_MAX_INTRON               => '250000',

	      # minimum coverage required to prevent splitting on long introns - keep it high!
	      GB_TARGETTED_MIN_SPLIT_COVERAGE       => '110',

	      # parameters for use in building genomic and miniseqs - don't touch these 
	      # unless you're sure you know what you're doing.
	      GB_TARGETTED_TERMINAL_PADDING                   => '20000',
	      GB_TARGETTED_EXON_PADDING                       => '200',
	      GB_TARGETTED_MINIMUM_INTRON                     => '1000',

	      # Parameters for genewise - targetted needs different parameters than similarity.
	      # Seriously, don't touch these unless you know exactly what you're doing.
	      # These are deliberately here and not in the genewise config as they should not 
	      # need to be changed, and will be a pain to fiddle with halfway through a build.
	      GB_TARGETTED_GENEWISE_MATRIX                    => 'BLOSUM80.bla',
	      GB_TARGETTED_GENEWISE_GAP                       => 20,
	      GB_TARGETTED_GENEWISE_EXTENSION                 => 8,

	      # genetype for Targetted_GeneWise
	      GB_TARGETTED_GW_GENETYPE              => 'TGE_gw',	   
	      GB_TARGETTED_MASKING => [],
	     #the above setting will lead no features being masked out, if [] is used no masking will take place, if [''] is used all repeats in the table will be masked out
	     #if only some of the sets of repeats wants to be masked out put logic names of the analyses in the array e.g ['RepeatMask', 'Dust']
	     GB_TARGETTED_SOFTMASK => 0, # set this to one if you want the repeats softmasked ie lower case rather than uppercase N's

	     );
sub import {
  my ($callpack) = caller(0); # Name of the calling package
  my $pack = shift; # Need to move package off @_
  
  # Get list of variables supplied, or else
  # all of Targetted:
  my @vars = @_ ? @_ : keys( %Targetted );
  return unless @vars;
  
  # Predeclare global variables in calling package
  eval "package $callpack; use vars qw("
    . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if ( defined $Targetted{ $_ } ) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$Targetted{ $_ };
	} else {
	    die "Error: Targetted: $_ not known\n";
	}
    }
}

1;
