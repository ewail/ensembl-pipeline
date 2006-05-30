# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::Config::GeneBuild::Similarity - imports global variables used by EnsEMBL gene building

=head1 SYNOPSIS
    use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Similarity;
    use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Similarity qw(  );

=head1 DESCRIPTION

Similarity is a pure ripoff of humConf written by James Gilbert.

humConf is based upon ideas from the standard perl Env environment
module.

It imports and sets a number of standard global variables into the
calling package, which are used in many scripts in the human sequence
analysis system.  The variables are first decalared using "use vars",
so that it can be used when "use strict" is in use in the calling
script.  Without arguments all the standard variables are set, and
with a list, only those variables whose names are provided are set.
The module will die if a variable which doesn\'t appear in its
C<%Similarity> hash is asked to be set.

The variables can also be references to arrays or hashes.

Edit C<%Similarity> to add or alter variables.

All the variables are in capitals, so that they resemble environment
variables.

=head1 CONTACT

=cut


package Bio::EnsEMBL::Pipeline::Config::GeneBuild::Similarity;

use strict;
use vars qw( %Similarity );

# Hash containing config info
%Similarity = (

	       GB_SIMILARITY_INPUTID_REGEX => '^([^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*)(?::([^:]+):([^:]+))?$',

	       # fill in one complete hash for each database from which blast 
	       # features are to be retrieved
	       GB_SIMILARITY_DATABASES => [
					  {				  
					    'type'       => 'Uniprot_mammal',
					    'threshold'  => '150',
					    'upper_threshold' => '',
					    'index'      => '/data/blastdb/Ensembl/uniprot',
					    'seqfetcher' => 'Bio::EnsEMBL::Pipeline::SeqFetcher::OBDAIndexSeqFetcher'
					   },
					   ],
	       
	       # minimum required parent protein coverage
	       GB_SIMILARITY_MULTI_EXON_COVERAGE           => 85,

	       # minimum required parent protein coverage
	       GB_SIMILARITY_SINGLE_EXON_COVERAGE          => 90,

	       # maximum allowed size of intron 
	       GB_SIMILARITY_MAX_INTRON         => 250000,

	       # minimum coverage required to prevent splitting on long introns - keep it high!
	       GB_SIMILARITY_MIN_SPLIT_COVERAGE => 110,

	       # low complexity threshold - transcripts whose translations have low
	       # complexity % higher than GB_MAX_LOW_COMPLEXITY will be discarded
	       GB_SIMILARITY_MAX_LOW_COMPLEXITY => 60,

	       # gene type for FPC_BlastMiniGenewise
	       GB_SIMILARITY_GENETYPE           => 'sim_gw_85_nomini',

	       # if [] is used no masking will take place 
	       # if [''] is used all repeats in the table will be masked out
	       # if only some of the sets of repeats wants to be masked out 
	       #   put logic names of the analyses in the array e.g ['RepeatMask', 'Dust']
	       # GB_SIMILARITY_MASKING => ['RepeatMask','Arma_ab_initio_RepeatMask'],
	       GB_SIMILARITY_MASKING => ['RepeatMask'],

               # set this to one if you want the repeats softmasked ie lower case rather than uppercase N's
	       GB_SIMILARITY_SOFTMASK => 0, 

	       # No similarity genes will be build with seeds overlapping the gene type put in this list. 
	       # If nothing is put, the default will be to take Targetted genewise genes
	       #GB_SIMILARITY_GENETYPEMASKED => ['TGE_gw','similarity_genewise'],
	       GB_SIMILARITY_GENETYPEMASKED => ['TGE_gw'],

	       # if one of the below is set, the above mask gene types will be used to filter out RESULTING genes
	       # that share gene/exon overlap with mask genes/exons of the above type.
	       GB_SIMILARITY_POST_GENEMASK => 1,
	       GB_SIMILARITY_POST_EXONMASK => 0,

	       # set this to one if you want to filter the blast scores before sending to BlastMiningenewise. 
	       # Currently used for anopheles. For Ano, speeds up the process by 10 folds
	       GB_SIMILARITY_BLAST_FILTER => 0, 
	   );

sub import {
  my ($callpack) = caller(0); # Name of the calling package
  my $pack = shift; # Need to move package off @_
  
  # Get list of variables supplied, or else
  # all of Similarity:
  my @vars = @_ ? @_ : keys( %Similarity );
  return unless @vars;
  
  # Predeclare global variables in calling package
  eval "package $callpack; use vars qw("
    . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if ( defined $Similarity{ $_ } ) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$Similarity{ $_ };
	} else {
	    die "Error: Similarity: $_ not known\n";
	}
    }
}

1;
