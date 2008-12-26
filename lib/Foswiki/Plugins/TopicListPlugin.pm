# This script Copyright (c) 2008 Impressive.media
# and distributed under the GPL (see below)
#
# Based on parts of GenPDF, which has several sources and authors
# This script uses html2pdf as backend, which is distributed under the LGPL
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

# =========================
package Foswiki::Plugins::TopicListPlugin;

# =========================
use strict;
use warnings;
use Error qw(:try);

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 12445$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.2';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'Gives you the possibility to generate a list of topics by macro or rest handler. Should be also optimized for a great number of topics';

# Name of this Plugin, only used in this module
$pluginName = 'TopicListPlugin';

# =========================


sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerRESTHandler('topiclist', \&_topicList);
    Foswiki::Func::registerTagHandler( 'GETTOPICLIST',\&_macrotopicList );
    
    return 1;
}

sub _macrotopicList{
	my ( $this, $params, $topic, $web ) = @_;
    my $searchWebs = $params->{"SEARCHWEBS"} || $web;
    my $pattern = $params->{"pattern"} || '*';
    my $casesensitive = $params->{"casesens"};
    $casesensitive = 1 if !defined $casesensitive;
    my $negate = $params->{"negate"} || 0;
    my $max = $params->{"max"} || 50;
    my $order = $params->{"order"} || '<';
    my $format = $params->{"format"} || "   * %WEB.%TOPIC\n";
    
    return _getTopicList($searchWebs,$pattern,$casesensitive,$negate,$max,$order,$format);
}
sub _topicList{
    my $session = shift;    
    my $web = $session->{webName};
    my $topic = $session->{topicName};  
    my $query = $session->{cgiQuery};
    my $searchWebs = $query->param("SEARCHWEBS") || $web;
    my $pattern = $query->param("pattern") || '*';
    my $casesensitive = $query->param("casesens") || 1;
    my $negate = $query->param("negate") || 0;
    my $max = $query->param("max") || 50;
    my $order = $query->param("order") || '<';
    my $format = $query->param("format") || "%WEB.%TOPIC\n";
 
    return _getTopicList($searchWebs,$pattern,$casesensitive,$negate,$max,$order,$format);
}

sub _getTopicList {
    my ($searchWebs,$pattern,$casesensitive,$negate,$max,$order,$format) = @_;

    my @webs = [];
    if($searchWebs eq "-all-") {
        @webs = Foswiki::Func::getListOfWebs();
    }
    else {
    	@webs = split (",",$searchWebs);
    }	
    
    my %topics = ();
    foreach my $web (@webs) {
    	# if this web does not exist, take the next one
    	if(!Foswiki::Func::webExists($web)) {
    		next;
    	}
    	   
    	$topics{$web} = _getTopicsOfWebByFunc($web,$pattern, $order, $max, $casesensitive, $negate);  	
    }
    
    return _getOutput($format,\%topics);
}

sub _getTopicsOfWebByFunc {
	my ($web,$pattern, $order, $max, $casesensitive, $negate) = @_;
    
    # filter by pattern and crop to the maximum size   
    _debug("web : $web");    
    my @tmp = Foswiki::Func::getTopicList($web);
    _debug("Topics found",@tmp);
    my $refTopics = \@tmp;
    _debug("max : $max");
    $refTopics = _filterTopicList($pattern,$casesensitive,$negate,$refTopics);
    
    my @topcis = splice @{$refTopics}, 0, $max;
    _debug("Topics spliced",@topcis);

    # as topics are read of from the FS, they normaly are in < order ( literally ), so if we sort > , flip the array 
    @topcis =  reverse @topcis if($order eq ">");
    
    return \@topcis;
}

sub _filterTopicList {
	my ($pattern,$casesensitive,$negate, $refTopics) = @_;
    return $refTopics if($pattern eq "*" || $pattern eq ".*");
    
    _debug("casesense",($casesensitive )); 
    
    my @result; 	    
	for(my $i = 0;$i < @{$refTopics};$i++) {
		# TODO: this is oOoO ugly!
		if($negate) {
			if($casesensitive) {
			     push (@result,$refTopics->[$i])  if ( $refTopics->[$i] !~ /$pattern/ );
			}
			else {
				 push (@result,$refTopics->[$i])  if ( $refTopics->[$i] !~ /$pattern/i );
			}
		}
		else {
			 if($casesensitive) {
                 push (@result,$refTopics->[$i])  if ( $refTopics->[$i] =~  /$pattern/ );
            }
            else {
                 push (@result,$refTopics->[$i])  if ( $refTopics->[$i] =~  /$pattern/i );
            }
		}		
	}
	_debug("Topics filtered",@result);
	return \@result;
}

sub _getOutput {
	my ($format, $refWebTopicPairs) = @_;
	my $output = "";
	foreach my $web ( keys %{$refWebTopicPairs}) {
		foreach my $topicName (@{$refWebTopicPairs->{$web}}) {
			my $tmp = $format;
			$tmp =~ s/%WEB/$web/g;
			$tmp =~ s/%TOPIC/$topicName/g;
			$output .= $tmp;			
		}		
	}
	return $output;	
} 

sub _debug {
    return if 1; #!$Foswiki::cfg{Plugins}{TopicListPlugin}{Debug};
    my ( $message, @param ) = @_;

    Foswiki::Func::writeDebug( "[TopicListPlugin]:" . $message );
    if ( @param > 0 ) {
        foreach my $p (@param) {
            Foswiki::Func::writeDebug( "[TopicListPlugin]://Param:" . $p );
        }
    }
    Foswiki::Func::writeDebug("[TopicListPlugin]:----------\n");
}

sub _warn {
    my ( $message, @param ) = @_;
    _debug( $message, @param );
    return Foswiki::Func::writeWarning($message);
}
1;

# vim: ft=perl foldmethod=marker
