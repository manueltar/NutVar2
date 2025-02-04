#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script fetches clusters of one2one orthologies between a
# given set of species
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $genomedb_adaptor = $reg->get_adaptor("Multi", "compara", "GenomeDB");

my @list_of_species = ("homo_sapiens","pan_troglodytes","macaca_mulatta");
#my @list_of_species = ("homo_sapiens","pan_troglodytes","macaca_mulatta","mus_musculus","rattus_norvegicus","canis_familiaris","bos_taurus","sus_scrofa","monodelphis_domestica","ornithorhynchus_anatinus","gallus_gallus","danio_rerio");
my $hash_of_species;
my @gdbs;
foreach my $species_binomial (@list_of_species) {
  push @gdbs, $genomedb_adaptor->fetch_by_name_assembly($species_binomial);
  $hash_of_species->{$species_binomial} = 1;
}

my $present_in_all = undef;
while (my $sp1_gdb = shift @gdbs) {
  foreach my $sp2_gdb (@gdbs) {
    print STDERR "# Fetching for ", $sp1_gdb->name, " - ", $sp2_gdb->name, "\n";
    my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs
      ('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
    my @orthologies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_orth)};
    my $count = 0; my $total_count = scalar @orthologies;
    foreach my $ortholog (@orthologies) {
      next unless ($ortholog->description =~ /one2one/);
      # Create a hash of stable_id pairs with genome name as subkey
      my ($gene1,$gene2) = @{$ortholog->gene_list};
      $count++;
      print STDERR "[$count/$total_count]\n" if (0 == $count % 100);
      $present_in_all->{$gene1->stable_id}{$sp1_gdb->name}{$gene2->stable_id} = 1;
      $present_in_all->{$gene1->stable_id}{$sp2_gdb->name}{$gene1->stable_id} = 1;
      $present_in_all->{$gene2->stable_id}{$sp1_gdb->name}{$gene2->stable_id} = 1;
      $present_in_all->{$gene2->stable_id}{$sp2_gdb->name}{$gene1->stable_id} = 1;
    }
  }
}

# This code below is optional and is only to sort out cases where all
# genomes are in the list and print the list of ids if it is the case
my @list = keys %$hash_of_species; my $set_num = scalar @list;
my $tagged_stable_id;
foreach my $stable_id (keys %$present_in_all) {
  my @set = $present_in_all->{$stable_id};
  my $present;
  foreach my $element (@set) {
    foreach my $name (@list) {
      $present->{$name} = 1 if (defined($element->{$name}));
    }
  }
  my $output_string;
  if (scalar keys %$present == scalar @list) {
    next if (defined($tagged_stable_id->{$stable_id})); #Print only once
    $tagged_stable_id->{$stable_id} = 1;
    $output_string = "$stable_id";
    my $stable_ids;
    $stable_ids->{$stable_id} = 1;
    foreach my $name (@list) {
      foreach my $id (keys %{$present_in_all->{$stable_id}{$name}}) {
        $stable_ids->{$id} = 1;
      }
    }
    print join(",", keys %$stable_ids), "\n";
  }
}

## For between species paralogies (dubious orthologs), use this instead
# my $mlss_para = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$sp1_gdb, $sp2_gdb]);
# my @paralogies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_para)};

