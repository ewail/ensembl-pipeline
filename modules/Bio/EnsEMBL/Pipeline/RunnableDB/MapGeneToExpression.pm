
# Cared for by Eduardo Eyras  <eae@sanger.ac.uk>
#
# Copyright GRL & EBI
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::RunnableDB::MapGeneToExpression

=head1 SYNOPSIS

    my $obj = Bio::EnsEMBL::Pipeline::RunnableDB::MapGeneToExpression->new(
									   -input_id  => $id,
									  );
    $obj->fetch_input;
    $obj->run;
    my %expression_map = %{ $obj->output };
    where @{ $expression_map{$transcript_id} } is an array of ests mapped to this transcript
    ests are here Bio::EnsEMBL::Transcript objects   

    $obj->write_output;


=head1 DESCRIPTION

Class to map genes read from an ensembl database to expression vocabulary via ESTs. 
ESTs are also read from an ensembl database. In principle, the typical situation
is to use ensembl genes and ests mapped to the genome.

=head1 CONTACT

eae@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Pipeline::RunnableDB::MapGeneToExpression;

use diagnostics;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::ESTFeatureAdaptor;
use Bio::EnsEMBL::Pipeline::GeneComparison::TranscriptCluster;
use Bio::EnsEMBL::Pipeline::GeneComparison::GeneCluster;
use Bio::EnsEMBL::Pipeline::GeneComparison::GeneComparison;
use Bio::EnsEMBL::Pipeline::GeneComparison::TranscriptComparator;
use Bio::EnsEMBL::DBSQL::DBEntryAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::ExpressionAdaptor;
use Bio::EnsEMBL::DBEntry;


use Bio::EnsEMBL::Pipeline::ESTConf qw(
				       EST_REFDBHOST
				       EST_REFDBUSER
				       EST_REFDBNAME
				       EST_REFDBPASS
				       EST_E2G_DBHOST
				       EST_E2G_DBUSER
				       EST_E2G_DBNAME
				       EST_E2G_DBPASS
				       EST_TARGET_DBNAME
				       EST_TARGET_DBHOST
				       EST_TARGET_DBUSER
				       EST_TARGET_DBPASS      
				       EST_TARGET_GENETYPE
				       EST_GENEBUILDER_INPUT_GENETYPE
				       EST_EXPRESSION_DBHOST
				       EST_EXPRESSION_DBNAME
				       EST_EXPRESSION_DBUSER
				       EST_EXPRESSION_DBPASS
				      );

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

######################################################################

sub new{
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  
   
  # where the dna is
  my $refdb = new Bio::EnsEMBL::DBSQL::DBAdaptor(
						  -host             => $EST_REFDBHOST,
						  -user             => $EST_REFDBUSER,
						  -dbname           => $EST_REFDBNAME,
						);
  
  # where the genes are
  my $ensembl_db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
						      '-host'   => $EST_TARGET_DBHOST,
						      '-user'   => $EST_TARGET_DBUSER,
						      '-dbname' => $EST_TARGET_DBNAME,
						      '-pass'   => $EST_TARGET_DBPASS,
						      '-dnadb'  => $refdb,
						     );
  

  # where the ests are (we actually want exonerate_e2g transcripts )
  unless( $self->dbobj){
    my $est_db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
						    '-host'   => $EST_E2G_DBHOST,
						    '-user'   => $EST_E2G_DBUSER,
						    '-dbname' => $EST_E2G_DBNAME,
						    '-dnadb'  => $refdb,
						   ); 
    $self->dbobj($est_db);
  }
  $self->est_db( $self->dbobj);
  $self->est_db->dnadb($refdb);
  $self->ensembl_db( $ensembl_db );
  $self->dna_db( $refdb );
  
  # database where the expression vocabularies are.
  # this is also where we are going to store the results
  my $expression_db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
							 '-host'   => $EST_EXPRESSION_DBHOST,
							 '-user'   => $EST_EXPRESSION_DBUSER,
							 '-dbname' => $EST_EXPRESSION_DBNAME,
							 '-pass'   => $EST_EXPRESSION_DBPASS,
							);
  
  $self->expression_db($expression_db);
  
  return $self;
  
}

#########################################################################
#
# GET/SET METHODS 
#
#########################################################################


sub ensembl_db{
  my ( $self, $db ) = @_;
  if ( $db ){
    $db->isa("Bio::EnsEMBL::DBSQL::DBAdaptor") || $self->throw("Input [$db] is not a Bio::EnsEMBL::DBSQL::DBAdaptor");
    $self->{'_ensembl_db'} = $db;
  }
  return $self->{'_ensembl_db'};
}

############################################################

sub expression_db{
  my ( $self, $db ) = @_;
  if ( $db ){
    $db->isa("Bio::EnsEMBL::DBSQL::DBAdaptor") || $self->throw("Input [$db] is not a Bio::EnsEMBL::DBSQL::DBAdaptor");
    $self->{'_expression_db'} = $db;
  }
  return $self->{'_expression_db'};
}

############################################################

sub est_db{
  my ( $self, $db ) = @_;
  if ( $db ){
    $db->isa("Bio::EnsEMBL::DBSQL::DBAdaptor") || $self->throw("Input [$db] is not a Bio::EnsEMBL::DBSQL::DBAdaptor");
    $self->{'_est_db'} = $db;
  }
  return $self->{'_est_db'};
}

############################################################

sub dna_db{
  my ( $self, $db ) = @_;
  if ( $db ){
    $db->isa("Bio::EnsEMBL::DBSQL::DBAdaptor") || $self->throw("Input [$db] is not a Bio::EnsEMBL::DBSQL::DBAdaptor");
    $self->{'_dna_db'} = $db;
  }
  return $self->{'_dna_db'};
}

#############################################################

sub ensembl_vc{
  my ($self,$vc) = @_;
  if ( $vc ){
    $self->{'_ensembl_vc'} = $vc;
  }
  return $self->{'_ensembl_vc'};
}

#############################################################

sub est_vc{
  my ($self,$vc) = @_;
  if ( $vc ){
    $self->{'_est_vc'} = $vc;
  }
  return $self->{'_est_vc'};
}

############################################################

sub ensembl_genes{
  my ( $self, @genes ) = @_;
  unless( $self->{_ensembl_genes} ){
    $self->{_ensembl_genes} =[];
  }
  if ( @genes ){
    $genes[0]->isa("Bio::EnsEMBL::Gene") || $self->throw("$genes[0] is not a Bio::EnsEMBL::Gene");
    push ( @{ $self->{_ensembl_genes} }, @genes );
  }
  return @{ $self->{_ensembl_genes} };
}

#############################################################

sub ests{
  my ( $self, @genes ) = @_;
  unless( $self->{_ests} ){
    $self->{_ests} =[];
  }
  if ( @genes ){
    $genes[0]->isa("Bio::EnsEMBL::Gene") || $self->throw("$genes[0] is not a Bio::EnsEMBL::Gene");
    push ( @{ $self->{_ests} }, @genes );
  }
  return @{ $self->{_ests} };
}

#########################################################################


sub gene_Clusters {
  my ($self, @clusters) = @_;
  if (@clusters){
    push ( @{$self->{'_gene_clusters'} }, @clusters);
  }
  return @{ $self->{'_gene_clusters'} };
}

#########################################################################

# this holds the gene_id for each transcript

sub _gene_ID{
  my($self,$transcript_id,$gene_id) = @_;
  unless ( $transcript_id && $gene_id ){
    $self->warn("Need two parameters, transcript_id: $transcript_id, gene_id: $gene_id ");
    unless (  $self->{_gene_id}{$transcript_id} ){
      $self->{_gene_id}{$transcript_id} ='none';
    }
    if ($gene_id){
      $self->{_gene_id}{$transcript_id} = $gene_id;
    }
    return $self->{_gene_id}{$transcript_id};
  }
}  

############################################################
#
# FETCH INPUT
#
############################################################

sub fetch_input {
  my( $self) = @_;
  
  # get genomic region 
  my $chrid    = $self->input_id;
  print STDERR "input_id: $chrid\n";
  if ( !( $chrid =~ s/\.(.*)-(.*)// ) ){
    $self->throw("Not a valid input_id... $chrid");
  }
  $chrid       =~ s/\.(.*)-(.*)//;
  my $chrstart = $1;
  my $chrend   = $2;
  print STDERR "Chromosome id = $chrid , range $chrstart $chrend\n";

  my $ensembl_gpa = $self->ensembl_db->get_StaticGoldenPathAdaptor();
  my $est_gpa     = $self->est_db->get_StaticGoldenPathAdaptor();

  my $ensembl_vc  = $ensembl_gpa->fetch_VirtualContig_by_chr_start_end($chrid,$chrstart,$chrend);
  my $est_vc      = $est_gpa->fetch_VirtualContig_by_chr_start_end($chrid,$chrstart,$chrend);

  $self->ensembl_vc( $ensembl_vc );
  $self->est_vc( $est_vc );

  # get ests (mapped with Filter_ESTs_and_E2G )
  $self->ests($self->est_vc->get_Genes_by_Type( $EST_GENEBUILDER_INPUT_GENETYPE, 'evidence' ));
  
  # get ensembl genes (from GeneBuilder)
  $self->ensembl_genes( $self->ensembl_vc->get_Genes_by_Type( $EST_TARGET_GENETYPE, 'evidence' ) );

}
  
############################################################
#
# RUN METHOD
#
############################################################

sub run{
  my ($self,@args) = @_;

  my @genes = $self->ensembl_genes;
  my @est   = $self->ests;

  # first cluster genes by locus
  # calculate on each cluster

  # for each gene in the cluster
  # for each transcript
  # calcultate the ests that map to this transcript

  # if there no genes, we finish a earlier
  unless ( $self->ests ){
    print STDERR "No ests in this region, leaving...\n";
    exit(0);
  }
  unless ( $self->ensembl_genes ){
    print STDERR "no genes found in this region, leaving...\n";
    exit(0);
  }
   
  # cluster the genes:
  my @clusters = $self->cluster_Genes( $self->ensembl_genes, $self->ests );
 
 CLUSTER:
  foreach my $cluster ( @clusters ){
    
    # get genes of each type
    my @genes = $cluster->get_Genes_of_Type( $EST_TARGET_GENETYPE );
    my @ests  = $cluster->get_Genes_of_Type( $EST_GENEBUILDER_INPUT_GENETYPE );
    
    # if we have genes of either type, let's try to match them
    if ( @genes && @ests ){
      print STDERR "Matching ".scalar(@genes)." ensembl genes and ".scalar(@ests)." ests\n"; 
      
      my @est_transcripts;
      foreach my $est ( @ests ){
	push ( @est_transcripts, $est->get_all_Transcripts );
      }
      
      foreach my $gene ( @genes ){
	foreach my $transcript ( $gene->get_all_Transcripts ){
	 
	  $self->_map_ESTs( $transcript, \@est_transcripts );
	}
      }
    }
    
    # else we could have only ensembl genes
    elsif(  @genes && !@ests ){
      # we have nothing to modify them, hence we accept them...
      print STDERR "Skipping cluster with no ests\n";
      next CLUSTER;
    }
    # else we could have only ests
    elsif( !@genes && @ests ){
      print STDERR "Cluster with no genes\n";
      next CLUSTER;
    }
    # else we could have nothing !!?
    elsif( !@genes && !@ests ){
      print STDERR "empty cluster, you must be kidding!\n";
      next CLUSTER
    }
  } # end of CLUSTER

  # before returning, check that we have written anything
  unless( $self->expression_Map ){
    exit(0);
  }
  return;
}

############################################################
#
# METHODS CALLED FROM RUN METHOD... DOING ALL THE MAGIC
#
############################################################

# this method cluster genes only according to genomic extent
# covered by the genes. The proper clustering of transcripts
# to give rise to genes occurs in _cluster_into_Genes()

sub cluster_Genes{
  my ($self, @genes) = @_;

  # first sort the genes by the left-most position coordinate ####
  my %start_table;
  my $i=0;
  foreach my $gene (@genes){
    $start_table{$i} = $self->_get_start_of_Gene( $gene );
    $i++;
  }
  my @sorted_genes=();
  foreach my $k ( sort { $start_table{$a} <=> $start_table{$b} } keys %start_table ){
    push (@sorted_genes, $genes[$k]);
  }
  
  # we can start clustering
  print "Clustering ".scalar( @sorted_genes )." genes...\n";
  
  # create a new cluster 
  my $cluster = Bio::EnsEMBL::Pipeline::GeneComparison::GeneCluster->new();
  my $cluster_count = 1;
  my @clusters;
  
  # before putting any genes, we must declare the types
  my $ensembl    = [$EST_TARGET_GENETYPE];
  my $est        = [$EST_GENEBUILDER_INPUT_GENETYPE];
  $cluster->gene_Types($ensembl,$est);

  # put the first gene into these cluster
  $cluster->put_Genes( $sorted_genes[0] );
  push (@clusters, $cluster);
  
  # loop over the rest of the genes
 LOOP:
  for (my $c=1; $c<=$#sorted_genes; $c++){
    my $found=0;
    
    # treat the clusters as ranges, so we only need to check if ranges overlap
    # for the moment this is enough
    my $gene_start = $self->_get_start_of_Gene( $sorted_genes[$c] );
    my $gene_end   = $self->_get_end_of_Gene(   $sorted_genes[$c] );
    
    # we need to do this each time, so that start/end get updated
    my $cluster_start = $cluster->start;
    my $cluster_end   = $cluster->end;

    if ( !( $gene_end < $cluster_start || $gene_start > $cluster_end ) ){
      $cluster->put_Genes( $sorted_genes[$c] );
    }
    else{
      # else, create a new cluster
      $cluster = new Bio::EnsEMBL::Pipeline::GeneComparison::GeneCluster; 
      $cluster->gene_Types($ensembl,$est);
      $cluster->put_Genes( $sorted_genes[$c] );
      $cluster_count++;
      push( @clusters, $cluster );
    }
  }

  print STDERR "returning ".scalar(@clusters)." clusters\n";
  return @clusters;
}			


#########################################################################

# this gives the left-most exon coordinate in a gene

sub _get_start_of_Gene{  
  my ($self,$gene) = @_;
  my $start;
  foreach my $tran ( $gene->get_all_Transcripts){
    foreach my $exon ( $tran->get_all_Exons ){
      unless ($start){
	$start = $exon->start;
      }
      if ( $exon->start < $start ){
	$start = $exon->start;
      }
    }
  }
  return $start;
}


#########################################################################

# this gives the right-most exon coordinate in a gene

sub _get_end_of_Gene{  
  my ($self,$gene) = @_;
  my $end;
  foreach my $tran ( $gene->get_all_Transcripts){
    foreach my $exon ( $tran->get_all_Exons ){
      unless ($end){
	$end = $exon->end;
      }
      if ( $exon->end > $end ){
	$end = $exon->end;
      }
    }
  }
  return $end;
}

#########################################################################
#
#  Method for mapping ESTs to genes:
#
#  For a given transcript,
#
# link to it all the ests that have exons which
# are consecutively included in the transcript
# (this will avoid linking to alternative variants which may in fact be expressed differently)
# allow the 5' and 3' exons of the ests to extend beyond the transcript
# (they may contain UTRs that we failed to annotate)

# ests           (1)###------###
#                          (2)#####--------#######
#           (3)########------###
#                (4)#####----#####
#             (5)####--------#####

#transcript      ######------######--------######

# (1),(2) and (3) would be linked. I'm not sure yet about cases like (4) and
# (5).

# Also, case (2) could be a hint for alternative polyA site if we have
# already annotated an UTR for that transcript. We could check for this case
# and only add (2) if there is no 3'UTR, to be sure.

# Case (3) could be also related to an alternative start of transcription,
# we could add it only for cases that a 5'UTR is not annotated.

# Part of the alternative polyA sites and start of transcription is
# correlated with alternative splicing so maybe this 'ambiguity' cases will
# not cause too many problems.

# We can keep the conditions tight for a start. As ests have been filtered,
# we could accept the splicing of (4) and (5) with some confidence, and
# we can include the check of UTRs for (2) and (3). ESTs that are not linked
# would be rejected in principle, I cannot predict yet how much data wil
# remain unused by doing this.

sub _map_ESTs{
  my ($self,$transcript,$ests) = @_;
  #if (  !( $ests[0]->isa('Bio::EnsEMBL::Transcript')) || !( $transcript->isa('Bio::EnsEMBL::Transcript')) ){
  #  $self->throw('expecting only transcripts, you have est = $ests[0] and transcript = $transcript');
  #} 

  # get only the ests that are in the SANBI database
  my @ests = $self->_in_SANBI( @{ $ests } );

  # check this transcript first:
  my $check = $self->_check_Transcript($transcript);
  unless ($check){
    return;
  }

  # a map from gene to est
  my %expression_map;
  
  # a comparison tool
  my $transcript_comparator = Bio::EnsEMBL::Pipeline::GeneComparison::TranscriptComparator->new();
  
 EST:
  foreach my $est (@ests){
    
    # check this transcript first:
    unless ($self->_check_Transcript($est)){
      next EST;
    }

    # compare this est
    my $merge = $transcript_comparator->test_for_semiexact_Merge($transcript,$est);

    # (this method checks exact exon boundary matches but
    # allows mismatches at outer end of the 5' and 3' exons)

    # check 5' and 3' ends in case ESTs give an alternative transcription 
    # start or alternative polyA site, respectively
    if ($merge){
      my $alt_start = $self->_check_5prime($transcript,$est);
      my $alt_polyA = $self->_check_3prime($transcript,$est);
      if ( $alt_start || $alt_polyA ){
	$self->_print_Transcript($transcript);
	$self->_print_Transcript($est);
      }
    }


    # if match, put est in $expression_map{ $transcript }
    if ($merge){
      $self->expression_Map($transcript,$est);
      
      # test results:
      my $t_id; 
      if ( $transcript->stable_id ){
	$t_id = $transcript->stable_id;
      }
      elsif( $transcript->dbID ){
	$t_id = $transcript->dbID;
      }
      my $e_id = $self->_find_est_id( $est);
      
      print STDERR "mapped $t_id to $e_id\n";

      #print STDERR $t_id."\t".$e_id."\n";
      #$self->_print_Transcript($transcript);
      #$self->_print_Transcript($est);
      #print STDERR "\n";
    }
  }
}

  

#########################################################################

sub _in_SANBI{
  my ($self,@ests) = @_;
  
  # @ests are transcript objects
  my %id_to_transcript;

  my @est_ids;
 EST:
  foreach my $est ( @ests ){
    my $est_id = $self->_find_est_id($est);
    unless ($est_id){
      #print STDERR "No accession found for ".$est->dbID."\n";
      next EST;
    }
    #print STDERR "est: $est, est_id: $est_id\n";
    if ( $est_id =~/(\S+)\.(\d+)/ ){
      $est_id = $1;
    }
    push( @est_ids, $est_id );
    $id_to_transcript{$est_id} = $est;
  }
  my $db = $self->expression_db;
  my $expression_adaptor = new Bio::EnsEMBL::Pipeline::DBSQL::ExpressionAdaptor($db);
  my @pairs = $expression_adaptor->get_libraryId_by_estarray( @est_ids );
  
  my @found_ests;
  foreach my $pair ( @pairs ){
    if ( $$pair[1] ){
      push ( @found_ests, $id_to_transcript{ $$pair[0] } );
    }
  }
  return @found_ests;
}


#########################################################################

sub expression_Map{
  my ($self,$transcript,$est) = @_;
  if ( $transcript ){
    my $transcript_id;
      if ($transcript->stable_id){
	$transcript_id = $transcript->stable_id;
      }
      elsif( $transcript->dbID ){
	$transcript_id = $transcript->dbID;
      }
    unless ( $self->{_est_map}{$transcript_id} ){
      $self->{_est_map}->{$transcript_id} = [];
    }
    if ($est){
      push ( @{  $self->{_est_map}->{$transcript_id} }, $est );
    }
  }
  return $self->{_est_map};
}

#########################################################################

sub _check_5prime{
  my ($self,$transcript,$est) = @_;
  my $alt_start = 0;
  
  # first find out whether the transcript has 5' UTR
  my $utr5;
  eval{
    $utr5 = $transcript->five_prime_utr;
  };
  unless( $utr5 ){
    return 0;
  }
  
  $transcript->sort;
  $est->sort;
  
  my $start_exon = $transcript->start_exon;
  #my $start_exon = $transcript->translation->start_exon;
  my $strand     = $start_exon->strand;
  foreach my $exon ( $transcript->get_all_Exons ){
    my $est_exon_count = 0;
    
    foreach my $est_exon ( $est->get_all_Exons ){
      $est_exon_count++;
      if ( $exon == $start_exon ){
	if ( $exon->overlaps( $est_exon ) ){
	  if ($strand == 1){
	    if ( $est_exon->start < $exon->start ){
	      print STDERR "potential alternative transcription start in forward strand\n";
	      $alt_start = 1;
	    }
	  }
	  if ($strand == -1){
	    if ( $est_exon->end > $exon->end ){
	      print STDERR "potential alternative transcription start in reverse strand\n";
	      $alt_start = 1;
	    }
	  }
	  if ($est_exon_count > 1){
	    print STDERR "There are more est exons upstream\n";
	    if ( $alt_start == 1){
	      return 1;
	    }
	  }
	}
      }
    }
  }
  return 0;
}


#########################################################################

sub _check_3prime{
  my ($self,$transcript,$est) = @_;
  my $alt_polyA = 0;
  
  # first find out whether the transcript has 5' UTR
  my $utr3;
  eval{
    $utr3 = $transcript->three_prime_utr;
  };
  unless( $utr3 ){
    return 0;
  }
  
  $transcript->sort;
  $est->sort;

  my $end_exon = $transcript->end_exon;
  #my $end_exon = $transcript->translation->end_exon;
  my $strand   = $end_exon->strand;
  
  foreach my $exon ( $transcript->get_all_Exons ){
    my $est_exon_count = 0;
    my @est_exons = $est->get_all_Exons;
    
    foreach my $est_exon ( @est_exons ){
      $est_exon_count++;
      if ( $exon == $end_exon ){
	if ( $exon->overlaps( $est_exon ) ){
	  if ($strand == 1){
	    if ( $est_exon->end > $exon->end ){
	      print STDERR "potential alternative polyA site in forward strand\n";
	      $alt_polyA = 1;
	    }
	  }
	  if ($strand == -1){
	    if ( $est_exon->start < $exon->start ){
	      print STDERR "potential alternative polyA site in reverse strand\n";
	      print STDERR "looking at : exon:".$exon->start."-".$exon->end." and est_exon:".$est_exon->start."-".$est_exon->end."\n";
	      $alt_polyA = 1;
	    }
	  }
	  if ($est_exon_count != scalar(@est_exons) ){
	    print STDERR "There are more est exons downstream\n";
	    print STDERR "est exon count = $est_exon_count, exons = ".scalar(@est_exons)."\n";
	    
	    if ( $alt_polyA ==1 ){
	      return 1;
	    }
	  }
	}
      }
    }
  }
  return 0;
}

#########################################################################

# method to calculate the exonic length of a transcript which is inside a gene

sub _transcript_exonic_length{
  my ($self,$tran) = @_;
  my $exonic_length = 0;
  foreach my $exon ($tran->get_all_Exons){
    $exonic_length += ($exon->end - $exon->start + 1);
  }
  return $exonic_length;
}

#########################################################################
# method to calculate the length of a transcript in genomic extent, 

sub _transcript_length{
    my ($self,$tran) = @_;
    my @exons= $tran->get_all_Exons;
    my $genomic_extent = 0;
    if ( $exons[0]->strand == -1 ){
      @exons = sort{ $b->start <=> $a->start } @exons;
      $genomic_extent = $exons[0]->end - $exons[$#exons]->start + 1;
    }
    elsif( $exons[0]->strand == 1 ){
      @exons = sort{ $a->start <=> $b->start } @exons;
      $genomic_extent = $exons[$#exons]->end - $exons[0]->start + 1;
    }
    return $genomic_extent;
}

#########################################################################

sub _check_Transcript{
  my ($self,$tran) = @_;
  
  my @exons = $tran->get_all_Exons;
  @exons = sort {$a->start <=> $b->start} @exons;
  
  for (my $i = 1; $i <= $#exons; $i++) {
    
    # check contig consistency
    if ( !( $exons[$i-1]->seqname eq $exons[$i]->seqname ) ){
      print STDERR "transcript ".$tran->dbID." (".$self->_find_est_id($tran).") is partly outside the contig, skipping it...\n";
      return 0;
    }
  }
  return 1;
}

#########################################################################
#
# METHODS INVOLVED IN WRITTING THE RESULTS
#
#########################################################################


#########################################################################

sub output{
  my ($self)= @_;
  
  return $self->expression_Map
}

#########################################################################
# get the est id throught the supporting evidence of the transcript

sub _find_est_id{
  my ($self, $est) = @_;
  my %is_evidence;
  foreach my $exon ($est->get_all_Exons){
    foreach my $evidence ( $exon->each_Supporting_Feature ){
      $is_evidence{ $evidence->hseqname } = 1;
    }
  }
  my @evidence = keys %is_evidence;
  unless ( $evidence[0] ){
    print STDERR "No evidence for ".$est->dbID.", hmm... possible sticky single exon gene\n";
  }
  return $evidence[0];
}
 
#########################################################################

# we write the results in the Xref table in the est_db:

sub write_output {
  my ($self) = @_;
  
  my $db = $self->expression_db;
  my $expression_adaptor = new Bio::EnsEMBL::Pipeline::DBSQL::ExpressionAdaptor($db);
  
  
  
  # recall we have stored the results in self->expression_Map as push ( @{ $self->{_est_map}{$transcript} }, $est );
  my %expression_map = %{ $self->expression_Map };
  
  foreach my $transcript_id ( keys %expression_map ){
    
    # $transcript_id should be a stable_id
    my @est_ids;
    foreach my $est ( @{ $expression_map{$transcript_id} }  ){
      my $est_id = $self->_find_est_id($est);
      if ( $est_id){
	my $est_id_no_version;
	if ( $est_id =~/(\S+)\.(\d+)/){
	  $est_id_no_version = $1;
	}
	else{
	  $est_id_no_version = $est_id;
	}
	push (@est_ids, $est_id_no_version);
      }
    }
    print STDERR "Storing pairs $transcript_id, @est_ids\n";
    $expression_adaptor->store_ensembl_link($transcript_id,\@est_ids);
  }
}


########################################################################

sub _print_Transcript{
  my ($self,$transcript) = @_;
  my @exons = $transcript->get_all_Exons;
  my $id;
  if ( $transcript->stable_id ){
    $id = $transcript->stable_id;
  }
  else{
    $id = $transcript->dbID;
  }
  my $evidence = $self->_find_est_id($transcript);
  print STDERR "$id ($evidence)\n";
  foreach my $exon ( @exons){
    print $exon->start."-".$exon->end."[".$exon->phase.",".$exon->end_phase."] ";
  }
  print STDERR "\n";
}

#########################################################################

1;
