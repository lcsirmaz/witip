####################
## wAboutPage.pm
####################
##
## Help, history, etc.
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################
=pod

=head1 wAboutPage.pm

Description and help of wITIP.

=head2 Procedures

=over 2

=item wAboutPage::Page($session)

Render the wITIP help page.

=item render_block($session,$anchor,$title,$text)

Internal procedure which renders a topic. $anchor is the internal link name
(id) of the topic without the leading letter w. $title is the title of
the section, finally $text is the text. In the text the following styling
can be used:

    L%<anchor>%<anchor text>%

to form and internal link; <anchor> is the internal link name without the
leading w; <anchor text> is the text which is presented. Use the letter E with
the same syntax for an extrnal link.

    S%<complete style>#<simple style>%

styles code depending on the configured style. If the second part starting
with # is missing, the whole text is printed as a code. If both parts are
present, the first part is printed when the complete style is in effect,
the second part for simple style (and commas are replaced by the current
separator character).

    <div class="indent"> ... </div>   

renders an indented  paragraph.

=item render_link($anchor,$text)

Internal procedure to render an internal link.

=item render_sample($session,$code)

Internal procedure which renders a sample code.

=back

=cut
###########################################################################

package wAboutPage;

use wHtml;
use strict;

my $seeas="<span class=\"seeas\">-&rsaquo;</span>"; # ->
my $seeas2="";

sub render_link {
    my($to,$text)=@_;
    return "<a href=\"$to\">$seeas$text</a>";
}
sub render_sample {
    my($session,$sample)=@_;
    if($sample =~ /^(.+)#(.+)$/){
       my($s1,$s2)=($1,$2);
       if($session->getconf("style")){ # simple style
          $sample=$s2;
          $sample =~ s/,/$session->getconf("sepchar")/ge;
       } else { # traditional style
          $sample=$s1;
       }
    }
    return "<span class=\"samplecode\">$sample</span>";
}

sub render_block {
    my($session,$ref,$title,$block)=@_;
    print "<div class=\"textblock\">\n",
      "<h2 id=\"w$ref\">$title</h2>\n";
    $block =~ s/L%([^%]+)%([^%]+)%/render_link("#w$1",$2)/ge;
    $block =~ s/S%([^%]+)%/render_sample($session,$1)/ge;
    $block =~ s/E%([^%]+)%([^%]+)%/render_link($1,$2)/ge;
    print $block;
    print "</div>\n";
}

# use L%<linkname>%<linktext>% for internal link to another topic
# and S%<full style>#<simple style>% for sample text

sub Page {
    my($session)=@_;
    wHtml::plain_header($session,"wITIP about", {
        lcss   => "about",
        banner => "wITIP",
        bodyattr => "onload=\"wi_onresize();\"",
        javascript => "
function wi_onresize(){
 var ht=Math.max(window.innerHeight, document.documentElement.clientHeight);
 if(ht>220)
   document.getElementById('leftblock').style.height= (ht-150)+'px';
}
window.onresize=wi_onresize;
function wi_showHelp(topic){
   alert('showing '+topic);
}
",
    });
    my $B="<span style=\"font-family: monospace; font-size: 1em;\">";
    my $E="</span>";
    print "<div style=\"height: 2px;\"> <!-- spacer --> </div>\n";
    print "<div class=\"main\">\n",
      "<table class=\"helptable\"><tbody><tr>\n";
    # legend
    print <<LEGEND;
<td class="legend">
<div class="ltitle">wITIP</div>
<ul>
<li>$seeas2<a href="#wabout">about</a></li></ul>
<div class="ltitle">Syntax</div>
<ul>
<li>$seeas2<a href="#wstyle">style</a></li>
<li>$seeas2<a href="#wvar">variables</a></li>
<li>$seeas2<a href="#wsequences">sequences</a></li>
<li>$seeas2<a href="#wentropy">entropy</a></li>
<li>$seeas2<a href="#wingleton">Ingleton</a></li>
<li>$seeas2<a href="#wexpr">expression</a></li>
<li>$seeas2<a href="#wmacros">macros</a></li>
<li>$seeas2<a href="#wconstr">constraints</a></li>
</ul>
<div class="ltitle">Checking</div>
<ul>
<li>$seeas2<a href="#wcheck">checking</a></li>
<li>$seeas2<a href="#wunroll">unrolling</a></li>
</ul>
<div class="ltitle">Session</div>
<ul>
<li>$seeas2<a href="#wconfigure">configure</a></li>
<li>$seeas2<a href="#wsave">print, save</a></li>
</ul>
<div class="ltitle">Other</div>
<ul>
<li>$seeas2<a href="#wmethod">method</a></li>
<li>$seeas2<a href="#whistory">history</a></li>
<li>$seeas2<a href="#wcopyright">author</a></li>
</ul>
</td>
LEGEND
    # content
    print "<td class=\"content\">\n",
      "<div class=\"left\" id=\"leftblock\">\n";
##################################################################
# ABOUT
    render_block($session,"about","About wITIP",<<BLOCK);
wITIP is a web based <b>I</b>nformation <b>T</b>heoretic <b>I</b>nequality 
<b>P</b>rover.
Linear entropy inequalities can be checked for validity, which means
whether the inequality is a consequence of the basic Shannon 
inequalities and the specified constraints.
<br>
wITIP uses extended syntax to enter expressions, a user friendly 
syntax checker, macro facility, and &quot;unrolling&quot; possibility
where complex entropy expressions are unrolled into a linear combination
of simple entropies.
<br>
To check an L%expr%entropy expression% for L%method%validity%, type it to the box
at the bottom of the &quot;check&quot; page:

<div class="indent">
  S%+1.234*H(X|Y)-12.234*I(A;B|H)&lt;=-2H(B,X,Y)#+1.234*(x|y)-12.234*(a,b|h)&lt;=-2bxy%
</div>

You can add L%constr%constraints% so that expressions are checked assuming
all constraints are true. In the list of constraints below the first one stipulates
that the variables form a Markov chain; the second one that the variables are 
completely independent; the third one is a conditional independence.

<div class="indent">
  S%Alpha -> Beta -> Gamma -> Delta# a -> b -> x -> y%
   &nbsp; &ndash; Markov chain <br>
  S%W1 || X || Y#u || v || w%
   &nbsp; &ndash; total independence<br>
  S%I(A;B|X,Y)=0#(a,b|xy)=0%
   &nbsp; &ndash; conditional independence
</div>

L%macros%Macros% are shorthands for (linear) entropy expressions; the macro 
below defines the conditional L%ingleton%Ingleton% expression:

<div class="indent">
  S%D(A;B;X;Y|E)=-I(A;B|E)+I(A;B|X,E)+(I(A;B|Y,E)+I(X,Y|E)#D(a,b,x,y|e)=-(a,b|e)+(a,b|xe)+(a,b|ye)+(x,y|e)%
</div>

The macro can be used in expressions, a possible invocation is 
S%D(A1,X;A2,Y;C;D|Z1,Z2)#D(ax,by,c,d|vw)%.
<br>

See also the description of the L%method%applied method%, the 
L%history%history%, and the  L%copyright%copyright% information.
<p></p>
BLOCK
########################################################################
# STYLE
    render_block($session,"style","Syntax style",<<SYNTAX_STYLE);

Entropy expressions can be entered using two different styles: either
<i>traditional</i> or <i>simplified</i>.  The traditional style follows the
style of the L%history%original ITIP software% created by Raymond W.  Yeung
and Ying-On Yan: random variables are identifiers, such as S%Winter% or
S%var_002%; variables in a list are separated by commas, and basic
information measures are entered in textbook style, such as
S%I(Winter,Spring;Fall|var_01)% denoting the conditional joint information
of S%Winter,Spring% and S%Fall% conditioned on S%var_01%.

<br>

Simplified style simplifies and speeds up entering queries.  Random
variables are restricted to lower case letters only (but see the description
of how L%var%random variables% are entered); variables are simply put next
to each other to denote their joint distribution; and basic information
measures are recognized without the letters S%H% or S%I%.  Thus S%(ax,by)%
is the joint information of the random variable pairs S%a,x% and S%b,y%.

<br>

The following two examples ask the validity of identical entropy
expressions; the first one is entered in traditional style, the second one
using simplified style. The first term in both queries is the 
L%ingleton%Ingleton expression%.

<div class="indent">
S%[A;B;X;Y]+I(Z;B|X)+I(Z;X|B)+I(B;X|Z) >= -3*I(Z;A,Y|B,X)%<br>
S%[a,b,c,d]+(e,b|c)+(e,c|b)+(b,c|e) >= -3*(e,ad|bc)%
</div>

Simplified style can be chosen by ticking the &quot;use simplified
syntax&quot; box in the L%configure%wITIP configuration%.  At the same place
other options can be set which changes how entropy expressions are parsed. 
Changing the style does not affect existing macros and constraints as their
internal representation is independent of the style.  However random
variables used in constraints might not be available anymore.

<p></p>

See the description of L%var%random variables% and L%sequences%variable
sequences% for more information.

<p></p>

<b>The examples are presented in the chosen style with the chosen
list separating characters.</b> To see the examples with other style
parameters, please change them in L%configure%wITIP configuration%.

<p></p>
SYNTAX_STYLE
#####################################################################
# VARIABLES
    render_block($session,"var","Random variables",<<RANDOM_VARS);
Using <i>traditional</i> style, random variables are arbitrary identifiers, 
that is 
Random variables and sequences of variables can be entered using two
different styles: either <i>traditional</i>, or <i>simplified</i>.<br>
In <i>traditional</i> style arbitrary identifier consisting of letters
and digits can denote a random variable, such as S%Winter% or
S%var_002%. This notation is similar to the one used in textbooks
where random variables are typically denoted by single capital letter
optionally followed by an index: S%A% or S%X_32%.<br>
The <i>simplified</i> style restricts how random variables can be
written &ndash; typically to a single lower case letter &ndash; 
but it lets enter complex entropy expressions in a more succinct way.
<p></p>
What sequences are allowed as random variables can be set in the 
L%configure%wITIP configuration%. Random variables can end with a
sequence primes such as in S%a'% or S%a''%.
<p></p>
RANDOM_VARS
#####################################################################
# SEQUENCES
    render_block($session,"sequences","Sequence of random variables",<<SEQUENCE);
The joint distribution of several random variables is denoted by
listing all individual variables next to each other. In <i>
traditional</i> style the variables are separated by commas as in
S%Spring,Summer, Winter, Fall%. In <i>simplified</i> style simply
write the variables next to each other, even without spaces; in this
style  both S%a b c% and S%abc% denotes the joint distribution of
the three variables S%a%, S%b%, and S%c%.
<p></p>
SEQUENCE
#####################################################################
# ENTROPY
    render_block($session,"entropy","Entropy terms",<<ENTROPY);
The entropy of the joint distribution of variables is denoted the
usual way as in S%H(Spring,Summer,Fall)#H(abx)%, the letter S%H% is
followed by a L%sequences%list of random variables% enclosed in
parentheses.
<br>
Other standard information measures, such as conditional entropy, mutual
information and conditional mutual information can be written similarly:
<ul><li>S%H(Spring | Summer)#H(a|x)% &ndash; conditional entropy,</li>
<li>S%I(A;B)#I(a,b)% &ndash; mutual information,</li>
<li>S%I(A;B|X)#I(a,b|x)% &ndash; conditional mutual information.</li>
</ul>
In <i>simplified</i> style these information measures can be further
simplified. A variable sequence stands for its own entropy; conditional
entropy and mutual information can be written without the leading letters
S%H% and S%I%.
<ul><li>S%ab% &ndash; the entropy of the variable pair S%a% and S%b%,</li>
<li>S%(ab|cd)% &ndash; conditional entropy, in standard style this is written as
S%H(a,b|c,d)%.
<li>S%(ab,cd)#(ab,cd)% mutual information, same as S%I(ab,cd)#I(ab,cd)%
(observe that S%ab% is the joint distribution of variables S%a% and S%b%),</li>
<li>S%(ab,cd|xy)#(ab,cd|xy)% conditional mutual information, same as
S%I(ab,cd|xy)#I(ab,cd|xy)%.
</ul>
<p></p>
ENTROPY
#####################################################################
# INGLETON
    render_block($session,"ingleton","Ingleton expression",<<INGLETON);
The <i>Ingleton expression</i> plays an important role in Information
Theory. wITIP uses a special syntax for this expression:
<div class="indent">
S%[A;B;X;Y]#[a,b,x,y]% is an abbreviation for<br>
&nbsp; &nbsp; S%-I(A;B)+I(A;B|X)+I(A;B|Y)+I(X;Y)#-I(a,b)+I(a,b|x)+I(a,b|y)+I(x,y)%;
</div>
there should be four L%sequences%variable sequences% inside the square
brackets.
<p></p>
INGLETON
#####################################################################
# EXPRESSIONS
    render_block($session,"expr","Entropy expression",<<EXPRESSION);
An <i>entropy expression</i> is a linear combination of 
L%entropy%entropy measures%, L%ingleton%Ingleton expression%,
and L%macros%macro invocations%. An example is
<div class="indent">
S%-1.234*H(X|Y) - 12.345I(A;B|H) + 3X(X;B|A,Y)#-1.234*(x|y) - 12.345(a,b|h) + 3X(x,b|ay)%
</div>
where S%X(;|)#X(,|)% is a L%macros%macro%. The S%*% sign between the
constant and the entropy term is optional and can be omitted.
<br>
When L%configure%allowed%, entropy expressions can be grouped by parentheses S%()%
(not recommended) or braces S%{}%, and multiplied by some constant:
<div class="indent">
S%-3*{H(A)+H(B)}-2{H(A|B)-H(B|A)}#-3*{a+b}-2{(a|b)-(b|a)}%
</div>
When using parentheses for grouping, omitting a single character might give
another syntactically correct expression, thus is more prune to error.
<p></p>
EXPRESSION
#####################################################################
# MACROS
    render_block($session,"macros","Macros",<<MACROS);
Next to standard information measures and the L%ingleton%Ingleton expression%, 
an L%expr%entropy expression% can also contain <i>macro invocations</i>.
Actually, a macro is a shorthand for a linear combination of 
L%expr%entropy terms%. Macros can be defined under the &quot;macros&quot; tab.
Tha definition starts with a capital letter from S%A% to S%Z% followed by the
argumnet list which is enclosed in parenteses. Arguments are separated by 
either S%;#,% or S%|% (the <i>pipe</i> symbol). The same macro name can
identify several different macros depending on the number of arguments and
the separator characters. The following lines define two different macros with
four arguments each:
<div class="indent">
S%T(X;Y|Z1;Z2) = 3I(Z1,X;Y|Z2)+2I(X;Y,Z2|Z1)+H(X,Y|Z1,Z2)#T(x,y|t,z) = 3(tx,y|z)+2(x,ty|z)+(t,z|xy)%
<br>
S%T(a|b|c;d) = -H(a|b,c)+2I(a;c|b,d)-7*[a;b;c;d]#T(a|b|c,d) = -(a|bc)+2(a,c|bd)-7*[a,b,c,d]%
</div>
Only variables in the argument list can be used in the right hand side. Macros
in the expression are expanded so should defined earlier. When invoking a
macro, each argument can be either a L%var%variable% or a L%sequences%variable list%;
the separators much match those in the definition. Thus
<div class="indent">
S%3*T(A,C;A,D|B,C;B,D) - 4T(X1,Z2|X2,Z2|Y1;Y2,Z2)#3*T(ac,ad|bc,bd) - 4T(xu|yu|t,u)%
</div>
expands the first and second definition, respectively.
<br>
Internally macros are stored
in &quot;unrolled&quot; form using only entropies; this form is printed when
clicking on a macro in the listing.
<br>To delete a macro click on the trash bin at the front of the macro. No other
action is possible apart from choosing which macros are to be deleted
Until you click on one of the actions at the top of the listing:
delete marked macros, delete all macros, or cancel.
<p></p>
MACROS
#####################################################################
# CONSTRAINTS
    render_block($session,"constr","Constraints",<<CONSTR);
Checking the L%method%validity% of an entropy expression is done
relative to a set of <i>constraints</i>. Constraints are added,
deleted, and enabled / disabled under the &quot;constraints&quot; tab.
To add a constraint, simply type it to the input line at the bottom, and
click on the &quot;add constraint&quot; button. Constraints can be
<ul><li>relation, that is two L%expr%entropy expressions% compared
by one of S%=%, S%&lt;=% or S%&gt;=%. Example:
<div class="indent">
  S%H(A,B,X)=H(A,B)+H(X)#abx=ab+x%
</div></li>
<li>functional dependency: the first L%sequences%variable list% is
determined by the second one. There should be exactly two lists in
this constraint.
<div class="indent">
    S%varlist1 : varlist2%
</div></li>
<li>independence: the variable lists are totally independent. There
must be two or more lists here.
<div class="indent">
   S%varlist1 . varlist2 . varlist3 . &middot;&middot;&middot;% <br>
   or<br>
   S%varlist1 || varlist2 || varlist3 || &middot;&middot;&middot;%
</div></li>
<li>Markov chain: the variable lists form a Markov chain. There must be at least
three terms here, and they should not form a trivial Markov chain.
<div class="indent">
  S%varlist1 / varlist2 / varlist 3 / &middot;&middot;&middot;% <br>
  or<br>
  S%varlist -&gt; varlist2 -&gt; varlist3 -&gt; &middot;&middot;&middot;%
</div></li>
</ul>
Enabled constraints have their checkbox ticked. Use these checkboxes to
change which constraints are actually used.
<br>
To delete any, or all, constraints, click on the trash bin. No further
action is possible apart from choosing which connstraints are to be deleted
until you click on one of the actions at the top of the listing: delete
marked constraints, delete all constraints, or cancel.
<p></p>
CONSTR
#####################################################################
# CHECKING
    render_block($session,"check","Checking expressions",<<CHECKING);
Checking the L%method%validity% of an entropy expression is done
relative to a set of <i>constraints</i>.
CHECKING
#####################################################################
# CHECKING
    render_block($session,"unroll","Unrolling",<<UNROLL);
What &quot;unroll&quot; means?
Checking the L%method%validity% of an entropy expression is done
relative to a set of <i>constraints</i>.
UNROLL
#####################################################################
# CONFIGURE
    render_block($session,"configure","Configuring wITIP",<<CONFIGURE);
What can you configure? How can it be done?
Be careful when changing any style option.
Checking the L%method%validity% of an entropy expression is done
relative to a set of <i>constraints</i>.
CONFIGURE
#####################################################################
# PRINTING, SAVING
    render_block($session,"save","Printing and saving your work",<<PRINTING);
The <i>session</i> determines your present working status.
You can print, save, an load.
What can you configure? How can it be done?
Checking the L%method%validity% of an entropy expression is done
relative to a set of <i>constraints</i>.
PRINTING
#####################################################################
# METHOD
    render_block($session,"method","Under the hood: how wITIP works?",<<METHOD);
wITIP transforms the question of the validity of the entered query
into a satisfiability of an LP problem.
What can you configure? How can it be done?
METHOD
#####################################################################
# HISTORY
    render_block($session,"history","History",<<HISTORY);
wITIP is a web based Information Theoretic Inequality Prover.  The server
side program was written in E%https://www.perl.org/%Perl% with the exception
of the LP solver engine, which is a C frontend to glpk, the
E%https://www.gnu.org/software/glpk/%Gnu Linear Programming Kit%. You can find
the source on the E%https://github.com/lcsirmaz/witip%github%.
<p></p>
The E%http://user-www.ie.cuhk.edu.hk/~ITIP%original ITIP software% 
was developed by <i>Raymond W. Yeung</i> and
<i>Ying-On Yan</i>, runs under MATLAB.
The stand alone version E%http://xitip.epfl.ch%Xitip% has graphical interface
and runs both in Windows and Linux.
<br>
This program is a port of E%https://github.com/lcsirmaz/minitip%minitip%, a 
command-line oriented version of ITIP.
<p></p>
HISTORY
#####################################################################
# COPYRIGHT
    render_block($session,"copyright","Author",<<COPYRIGHT);
wITIP is a free, open-source software available at
E%https://github.com/lcsirmaz/witip%github%. You may redistribute it and/or
modify under the terms of the 
E%GNU General Public License (GPL)%http://www.gnu.org/licenses/gpl.html% 
as published by the Free Software Foundation.
<br>
There is ABSOLUTELY NO WARRANTY, use at your own risk.
<br>
Copyright &copy; 2017 Laszlo Csirmaz, Central European University, Budapest
<p></p>
COPYRIGHT
    print "</div><!-- leftblock -->\n",
      "</td></tr></tbody></table>\n";
    print "</div><!-- main -->\n";

    wHtml::html_tail();
}

1;
