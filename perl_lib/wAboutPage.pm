####################
## wAboutPage.pm
####################
##
## Help, history, etc.
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright 2017-2024 Laszlo Csirmaz, UTIA, Prague
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################
=pod

=head1 wITIP perl modules

=head2 wAboutPage.pm

Render the "about" page of wITIP

=head2 Procedures

=over 2

=item wAboutPage::Page($session)

Render the wITIP help page.

=item render_block($session,$anchor,$title,$text)

Local procedure which renders a topic. $anchor is the internal link name
(id) of the topic without the leading letter w. $title is the title of
the section, finally $text is the text. In the text the following styling
can be used:

    L%<anchor>%<anchor text>%
    E%<anchor>%<anchor text>%

to form and internal and external link, respectively; <anchor> is the line
name, for internal links it is without the leading w; <anchor text> is the 
text which is presented.

    S%<complete style>#<simple style>%

styles code depending on the configured style. If the second part starting
with # is missing, the whole text is printed as a code. If both parts are
present, the first part is printed when the complete style is in effect,
the second part for simple style (and commas are replaced by the current
separator character).

    <div class="indent"> ... </div>   

renders an indented  paragraph.

=item render_link($anchor,$text)

Local procedure to render an internal link.

=item render_sample($session,$code)

Local procedure which renders a sample code. Replaces < and > symbols
by &lt; and &ge;

=back

=cut
###########################################################################

package wAboutPage;

use wHtml;
use strict;

my $seeas=""; #"<span class=\"seeas\">-&rsaquo;</span>"; # ->
my $seeas2="";

sub render_link {
    my($to,$text)=@_;
    my $target="";
    if($to =~ /^http/){ $target=" target=\"_blank\""; }
    return "<a href=\"$to\"$target>$seeas$text</a>";
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
#    $sample =~ s/&/&amp;/g;
    $sample =~ s/</&lt;/g;
    $sample =~ s/>/&gt;/g;
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
",
    });
    my $B="<span style=\"font-family: monospace; font-size: 1em;\">";
    my $E="</span>";
    print "<div style=\"height: 2px;\"> <!-- spacer --> </div>\n";
    print "<div class=\"hmain\">\n",
      "<table class=\"helptable\"><tbody><tr>\n";
    # menu
    print <<LEGEND;
<td class="menu">
<div class="ltitle">wITIP</div>
<ul>
<li>$seeas2<a href="#wabout">introduction</a></li></ul>
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
<div class="ltitle">Query</div>
<ul>
<li>$seeas2<a href="#wcheck">checking</a></li>
<li>$seeas2<a href="#wunroll">unroll</a></li>
</ul>
<div class="ltitle">Configure</div>
<ul>
<li>$seeas2<a href="#wconfigure">appearence</a></li>
<li>$seeas2<a href="#wconfstx">syntax</a></li>
<li>$seeas2<a href="#wconfother">other</a></li>
</ul>
<div class="ltitle">Session</div>
<ul>
<li>$seeas2<a href="#wprint">print, save</a></li>
<li>$seeas2<a href="#wquit">quit</a></li>
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
    render_block($session,"about","What is wITIP?",<<BLOCK);
wITIP is a web-based <b>I</b>nformation <b>T</b>heoretic <b>I</b>nequality 
<b>P</b>rover.
Linear entropy inequalities can be checked for validity, that is,
whether the inequality is a consequence of the basic Shannon 
inequalities and the specified constraints.
<br>
wITIP uses extended syntax for expressions, a user-friendly 
syntax checker, macros, and &quot;unroll&quot;,
where complex entropy expressions can be seen as a linear combination
of simple entropies. 
<br>
<b>L%check%Checking%</b> &ndash; to check an L%expr%entropy expression% for L%method%validity%, 
enter such an expression to the box
at the bottom of the &quot;check&quot; page:

<div class="indent">
  <!--<span class="resfalse">false</span>--> S%+1.234*H(X|Y)-12.234*I(A;B|H) <= -2H(B,X,Y)#+1.234*(x|y)-12.234*(a,b|h) <= -2bxy%
</div>
<b>L%constr%Constraints%</b> &ndash;
can be added and queries are checked assuming all constraints are true. 
The constraint below stipulates that the variable sets form a Markov chain:
<div class="indent">
  S%Alpha,Beta -> Beta,Gamma -> Gamma,Delta -> Tau# ab -> bc -> cx -> y%
</div>
<b>L%macros%Macros%</b> &ndash;
are shorthands for (linear) entropy expressions; the macro
below defines the conditional L%ingleton%Ingleton% expression:
<div class="indent">
  S%D(A;B;X;Y|E) = -I(A;B|E)+I(A;B|X,E)+I(A;B|Y,E)+I(X,Y|E)#D(a,b,x,y|e)=-(a,b|e)+(a,b|xe)+(a,b|ye)+(x,y|e)%
</div>
After it has been defined, the macro can be used in any expression.
<br>
<b>L%unroll%Unroll%</b> &ndash;
calculates the difference of two L%expr%entropy expressions% as a linear 
combination of simple entropies:
<div class="indent">
S%D(A1,X;A2,Y;C;D|Z1,Z2) =? [A1,X,Z1,Z2;A2,Y,Z1,Z2;C,Z1;D,Z1]#D(ax,by,c,d|vw) =? [axvw,byvw,cv,dv]%
<br>
S%H(C,D,Z1)-H(C,D,Z1,Z2)#cdv-cdvw%
</div>
<p></p>
See also the description of the L%method%applied method%, the
L%history%history% of wITIP, and the L%copyright%copyright% information.
<p></p>
BLOCK
########################################################################
# STYLE
    render_block($session,"style","Syntax style",<<SYNTAX_STYLE);

Entropy L%expr%expressions% can be entered using two different styles:
<i>traditional</i> or <i>simplified</i>.  The traditional style follows
that of the L%history%original% ITIP software:
random variables are identifiers, such as S%Winter% or
S%var_002%; variables in a list are separated by commas, and basic
information measures are entered in the textbook style:
<div class="indent">
  S%I(Winter,Spring; Fall | var_01)%
</div>
which denotes the conditional joint information of S%Winter,Spring% and 
S%Fall% conditioned on S%var_01%.
<br>
The <i>simplified</i> style simplifies and speeds up entering queries.
Random variables are restricted to lower case letters only (but see the
L%var%description%); variables are simply put next
to each other to denote their joint distribution; and basic information
measures are recognized without the letters S%H% or S%I%.  Thus 
S%(ax,by)#(ax,by)%
is the joint information of the random variable pairs S%a,x% and S%b,y%.

<br>

The following two examples query the validity of identical entropy
expressions; the first one is entered in traditional style, the second one
using simplified style. The first term is the L%ingleton%Ingleton expression%.

<div class="indent">
<!-- <span class="restrue">true</span> --> S%[A;B;X;Y]+I(Z;B|X)+I(Z;X|B)+I(B;X|Z) >= -3*I(Z;A,Y|B,X)%<br>
<!-- <span class="restrue">true</span> --> S%[a,b,c,d]+(e,b|c)+(e,c|b)+(b,c|e) >= -3*(e,ad|bc)%
</div>

The style can be chosen and fine-tuned in the L%configure%wITIP configuration%.
See the description of L%var%random variables% and L%sequences%variable
sequences% for more information.

<p></p>

<b>The examples are shown in the chosen style with the chosen list-separating character.</b>
To see how the examples look like using different style
parameters, please L%configure%change the style%.

<p></p>
SYNTAX_STYLE
#####################################################################
# VARIABLES
    render_block($session,"var","Random variables",<<RANDOM_VARS);
Random variables and variable sequences can be entered using two
different L%style%style%: <i>traditional</i>, or <i>simplified</i>.
<br>
In <i>traditional</i> style arbitrary identifiers (consisting of letters,
digits and underscore) can denote random variables, such as S%Winter% or
S%var_002%. This notation is similar to the one used in textbooks
where random variables are typically denoted by a single capital letter
optionally followed by an index or a prime: S%A%, S%X_32% or S%X'%.
<br>
The <i>simplified</i> style restricts how random variables can be
written &ndash; typically to a single lower case letter, which
allows entering complex entropy expressions in a more succinct way.
Depending on the L%configure%configuration%, variable names in the simple style
might also end with a single digit, or a sequence of digits.
<p></p>
In both styles wITIP allows primes appended to variable names such as
S%a'% or S%a''%.
<p></p>
RANDOM_VARS
#####################################################################
# SEQUENCES
    render_block($session,"sequences","Sequence of random variables",<<SEQUENCE);
The joint distribution of several random variables is denoted by
listing all individual variables next to each other. In 
<i>traditional</i> style the variables are separated by commas as in
S%Spring,Summer, Winter, Fall% (spaces are optional). In <i>simplified</i>
style simply write the variables next to each other either with or 
without spaces; that is, both S%a b c% and S%abc% denote the joint distribution of
the three variables S%a%, S%b%, and S%c%.
<p></p>
SEQUENCE
#####################################################################
# ENTROPY
    render_block($session,"entropy","Entropy terms",<<ENTROPY);
The entropy of (the joint distribution of) a variable list is 
written the usual way:
<div class="indent">S%H(Spring,Summer,Fall)#H(abx)%,</div>
where the letter S%H% is followed by a L%sequences%variable sequence%
enclosed in parentheses.
<br>
Other standard information measures can be written similarly:
<ul><li>S%H(Spring;Winter | Summer)#H(ab|x)% &ndash; conditional entropy,</li>
<li>S%I(A,B;X)#I(ab,x)% &ndash; mutual information,</li>
<li>S%I(A,B;C|X,Y)#I(ab,c|xy)% &ndash; conditional mutual information.</li>
</ul>
In <i>simplified</i> style these information measures can be further
simplified. A variable sequence stands for its own entropy; conditional
entropy and mutual information can be written without the leading letters
S%H% and S%I%.
<ul><li>S%ab% &ndash; the entropy of the variable pair S%a% and S%b%,</li>
<li>S%(ab|cd)% &ndash; conditional entropy &ndash; in traditional style 
this should be written as S%H(a,b|c,d)%.
<li>S%(ab,cd)#(ab,cd)% mutual information, same as S%I(ab,cd)#I(ab,cd)%,</li>
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
S%[A;B;X;Y]#[a,b,x,y]% is an abbreviation for the Ingleton expression<br>
&nbsp; &nbsp; S%-I(A;B)+I(A;B|X)+I(A;B|Y)+I(X;Y)#-I(a,b)+I(a,b|x)+I(a,b|y)+I(x,y)%.
</div>
There must be four L%sequences%variable sequences% inside the square
brackets. If &quot;reverse Ingleton notation&quot; is ticked in the 
L%confstx%config% tab, then the same expression is abbreviated as
S%[X;Y;A;B]#[x,y,a,b]%
<p></p>
INGLETON
#####################################################################
# EXPRESSIONS
    render_block($session,"expr","Entropy expression",<<EXPRESSION);
An <i>entropy expression</i> is a linear combination of 
L%entropy%entropy terms%, L%ingleton%Ingleton expression%,
and L%macros%macro invocations%. An example is
<div class="indent">
S%-1.234*H(X|Y) - 12.345I(A;B|H) + 3X(X;B|A,Y)#-1.234*(x|y) - 12.345(a,b|h) + 3X(x,b|ay)%
</div>
where S%X(;|)#X(,|)% is a L%macros%macro%. The S%*% sign between the
constant and the following term is optional and can be omitted.
<br>
When L%configure%allowed%, entropy expressions can be grouped by parentheses S%()%
(not recommended) or by braces S%{}%; and the whole group can be multiplied by 
some constant:
<div class="indent">
S%-3*{H(A)+H(B)-2{H(A|B)-H(B|A)}}#-3*{a+b-2{(a|b)-(b|a)}}%
</div>
Using parentheses for grouping may lead to unintended but 
syntactically correct expressions.
<p></p>
EXPRESSION
#####################################################################
# MACROS
    render_block($session,"macros","Macros",<<MACROS);
Next to L%entropy%entropy terms% and the L%ingleton%Ingleton expression%, 
an L%expr%expression% can also contain <i>macro invocations</i>.
Actually, a macro is a shorthand for a linear combination of other
L%expr%entropy terms%. Macros can be defined under the &quot;macros&quot; tab.
The macro definition starts with a capital letter from S%A% to S%Z% followed by the
argument list enclosed in parentheses. Arguments are separated by 
either S%;#,% or S%|% (the list separator character or the <i>pipe</i> symbol).
The same macro name can
identify several different macros depending on the number of arguments and
the argument separators. The following lines define two different macros with
four arguments each:
<div class="indent">
S%T(X;Y|Z1;Z2) = 3I(Z1,X;Y|Z2)+2I(X;Y,Z2|Z1)+H(X,Y|Z1,Z2)#T(x,y|t,z) = 3(tx,y|z)+2(x,ty|z)+(t,z|xy)%
<br>
S%T(a|b|c;d) = -H(a|b,c)+2I(a;c|b,d)-7*[a;b;c;d]#T(a|b|c,d) = -(a|bc)+2(a,c|bd)-7*[a,b,c,d]%
</div>
Only variables in the argument list can be used on the right-hand side. Macros
appearing in macro definitions are expanded immediately so must be defined earlier.
When invoking a
macro, each argument can be a L%var%variable% or a L%sequences%variable list%,
and the separators much match those in the definition. Thus
<div class="indent">
S%3*T(A,C;A,D|B,C;B,D) - 4T(X1,Z2|X2,Z2|Y1;Y2,Z2)#3*T(ac,ad|bc,bd) - 4T(xu|yu|t,u)%
</div>
expands the first and second definition, respectively.
<br>
Internally, macros are stored
in expanded form using only entropies; this form is displayed when
clicking on a macro in the listing.
<br>To delete a macro, click on the trash bin icon next to the macro. 
After a trash bin icon has been selected no other action is possible (apart from
selecting / deselecting other macros) until one of the buttons
above the macros (delete, delete all, or cancel) is clicked.

<p></p>
MACROS
#####################################################################
# CONSTRAINTS
    render_block($session,"constr","Constraints",<<CONSTR);
Checking the L%method%validity% of an entropy query is done
relative to a set of selected <i>constraints</i>. Constraints can be added,
deleted, enabled or disabled under the &quot;constraints&quot; tab.
To add a constraint simply enter it into the input line at the bottom, and
click on the &quot;add constraint&quot; button. A constraint can be
<ul><li>relation, that is two L%expr%entropy expressions% compared
by one of S%=%, S%<=% or S%>=%. Example:
<div class="indent">
  S%H(A,B,X) = H(A,B)+H(X)#abx = ab+x%
</div></li>
<li>functional dependency: the first L%sequences%sequence% is
determined by the second one. There should be exactly two lists in
this constraint. Example:
<div class="indent">
    S%A : X,Y#a : xy% <br>
    or <br>
    S%A &lt;&lt; X,Y#a &lt;&lt; xy%
</div></li>
<li>independence: the sequences are totally independent. There
must be at least two sequences.
<div class="indent">
   S%A . B1,B2 . X,Y . &middot;&middot;&middot;#a . bc . xy . &middot;&middot;&middot;% <br>
   or<br>
   S%A || B1,B2 || X,Y || &middot;&middot;&middot;#a || bc || xy || &middot;&middot;&middot;%
</div></li>
<li>Markov chain: the lists form a Markov chain. There must be at least
three terms here, and they should not form a trivial Markov chain.
<div class="indent">
  S%A / B1,B2 / X,Y / &middot;&middot;&middot;#a / bc / uv / &middot;&middot;&middot;% <br>
  or<br>
  S%A -> B1,B2 -> X,Y -> &middot;&middot;&middot;#a -> bc -> uv -> &middot;&middot;&middot;%
</div></li>
<li>common information: the first list acts as the common information of
the other two: it is determined by all of them, and has the maximal entropy.
<div class="indent">
  S%A,B &lt;&lt; B1,B2 / X,Y #ab &lt;&lt; bc / uv %
</div></li>
</ul>
Enabled constraints have their checkbox ticked. Use the checkboxes to
enable or disable constraints.

<br>

To delete any or all constraints, click on the trash bin icon next to them. 
When changing which constraints are enabled, or when deleting them, no further
action is possible until one of the buttons above the constraint list is 
clicked.

<p></p>
CONSTR
#####################################################################
# CHECKING
    render_block($session,"check","Checking queries",<<CHECKING);
Enter your query into the bottom box of the &quot;check&quot; tab. A 
<i>query</i> is just two L%expr%entropy expressions% connected by
S%=% (equality), S%>=% (greater than or equal to), or S%<=% 
(less than or equal to) such as
<div class="indent">
S%[A;B;C;D]+I(A;B|Z)+I(B;Z|A)+I(Z;A|B) >= -3*I(C,D;Z|A,B)#[a,b,c,d]+(a,b|z)+(b,z|a)+(z,a|b) >= -3*(cd,z|ab)%
</div>
If the query is parsed successfully, it is added to the list above the
query box, and passed to the L%method%LP solver% for checking.  Depending on
the response time of the LP solver, either the result is shown immediately,
or it appears later, when the solver finishes its work.  The result of the
query can be
<div class="textindent">
<table class="sample"><tbody>
<tr><th><span class="restrue">true</span></th><td>
   the query is a consequence of the non-negativity of the basic Shannon
   information measures (and the  L%constr%constraints% if checked with
   constraints).</td></tr>
<tr><th><span class="resfalse">false</span></th><td>
   the query is <b>not</b> a consequence of the above collection.</td></tr>
<tr><th><span class="resonly">only &ge;</span></th><td>
   the query asked for equality, but only &ge; holds (would get
   <span class="restrue">true</span> when asked for S%>=%, and 
   <span class="resfalse">false</span> when asked for S%<=%).</td></tr>
<tr><th><span class="resonly">only &le;</span></th><td>
   the query asked for equality, but only &le; holds (would get
   <span class="resfalse">false</span> when asked for S%>=%, and 
   <span class="restrue">true</span> when asked for S%<=%).</td></tr>
<tr><th><span class="resonly">0 &ge; 0</span></th><td>
   the query simplifies to 0 &ge; 0, thus it is <span class="restrue">true</span>.</td></tr>
<tr><th><span class="resonly">0 = 0</span></th><td>
   the query simplifies to 0 = 0.</td></tr>
<tr><th><span class="resother">timeout</span></th><td>
   the LP solver failed to solve the problem in the allocated time.</td></tr>
<tr><th><span class="resother">failed</span></th><td>
   the LP solver failed, probably the problem is too large, or 
   numerically unstable.</td></tr>
</tbody></table>
</div>

By default the query is checked relative to the enabled
L%constr%constraints%, in which case the query is marked with <span
class="constraint">C</span>.
This means that these constraints are assumed to
hold, and can be used along the basic Shannon inequalities in the derivation
of the query.  This mark does not mean that some (or all) 
of the constraints are actually necessary to derive the result, only 
that the checking was performed with constraints.

<p></p>
CHECKING
#####################################################################
# CHECKING
    render_block($session,"unroll","Unroll",<<UNROLL);
The L%expr%entropy expressions% around S%=?% are expanded as linear combination of
plain entropies and their difference is printed below the query:
<div class="textindent">
<table class="sample"><tbody>
<tr><th><span class="resother">unroll</span></th><td>
  S%[A;B;C;D] =? I(A;B|C)+I(A;B|D)+I(A;B)#[a,b,c,d] =? (a,b|c)+(a,b|d)+(c,d)%
  </td></tr>
<tr><th></th><td>
  S%-H(A)-H(B)+H(A,B)#-a-b+ab%
  </td></tr>
</tbody></table>
</div>
When the two sides expand to the the same expression, the result is S%0%. 
The mnemonic for &quot;=?&quot;
can be: what are the missing terms on the right hand side which make the two
expressions the same?
<br>
This operation does not involve any further computation, thus the result 
appears immediately.
<p></p>
UNROLL
#####################################################################
# CONFIGURE
    render_block($session,"configure","Configure appearance",<<CONFIGURE);
You can set and change many wITIP features under the &quot;config&quot; tab.
The selected font family and font size is used to show the entered
macros, constraints, and queries. This choice does not affect the font
used in L%print%printing%.
<br>
&quot;Table height&quot; sets the maximum height of the macro, 
constraint and query tables.
<p></p>
CONFIGURE
    render_block($session,"confstx","Choose and fine tune wITIP syntax",<<CFGSYNTAX);
The details how wITIP processes the entered text can be set under the 
&quot;config&quot; tab.
<p></p>

<strong>Syntax</strong><br>
Determine whether traditional or simplified L%style%style% should be used;
use reverse L%ingleton%Ingleton% expression;
can parentheses S%()% or braces S%{}% enclose subexpressions;
and finally whether variables can or cannot end in a sequence of primes (apostrophes).
<p></p>

<strong>Simple style details</strong><br>
By default, simple style allows only single lower case letters (optionally
followed by primes if configured) as variable names. You can
extend the recognized variable names (before the primes) by allowing one
or more of the following possibilities:
<ul><li>a (lower case) letter and a single digit: S%a1%</li>
<li>a letter followed by any digit sequence: S%a123%</lI>
<li>a letter, an underscore and a single digit: S%a_2%</li>
<li>a letter, an underscore, and a digit sequence: S%a_4321%</li>
</ul>
By default, none of them are enabled as it would be
easier to enter unintended but syntactically correct queries.
<br>
The simple style list separator character can be chosen from a
short list of possibilities. Use the one which fits your taste.
<p></p>
CFGSYNTAX
    render_block($session,"confother","Other wITIP features",<<CONFOTHER);
Use the &quot;config&quot; tab to set some miscellaneous wITIP features.
<p></p>

<strong>Unused arguments in a macro definition</strong><br>
By default, all macro arguments must be used in the final (fully expanded)
macro text. Uncheck this option if you want to use macro definitions
like the next one, in which the first argument S%U#u% cancels out:
<div class="indent">
S%A(U,V,W)=I(U;V|W)+H(V|U,W)#A(u,v,w)=(u,v|w)+(v|uw)%
</div>
<strong>LP response time</strong><br>
Each L%check%query% is passed to the L%method%LP solver% which answers
the question. The default time limit is 5 seconds. You can 
set this limit higher (up to 10 minutes), or lower (down to 1 second).
Typically the more random variables are used in the query, the longer
the LP solver works. The increase in the execution time is very steep
as the problem size grows exponentially. Up to six or seven variables 
the result is almost immediate; over thirteen variables due to numerical
instability the LP solver might fail to solve the problem or could return
a wrong solution.
The query is marked by <span class="resother ybg">timeout</span> if the 
time limit was exceeded, and by <span class="resother ybg">failed</span>
if the solver failed.
<p></p>
CONFOTHER
#####################################################################
# PRINT, EXPORT / IMPORT
    render_block($session,"print","Print, export and import",<<PRINTING);
There is no need to save your work: when opening a wITIP session it
automatically restores the latest content. To create a backup (or a snapshot),
export the session. The exported content can be restored by importing it.
Rather than entering constraints and macros one by one, they can be added
in bulk from an external command file. An editable command file &ndash; 
recreating the present set of macros, constraints, and the last query 
&ndash; is available for download. Use the &quot;session&quot; tab for
these options.

<p></p>

<strong>Printing</strong><br>
Click on &quot;print&quot; to print out the actual list of macros, 
constraints and queries.
A new page is opened showing these items. You can edit the main title 
(by default the session ID and the current date / time), and the
section titles as well. Buttons on the right hand side
hide a whole section, or some part of it, which 
can be useful if, for example, you do not need the expanded (internal)
form of the constraints. Entropy expressions are printed using the default 
font (and not the one configured). Expanded forms use the current syntax
style set in the L%configure%configuration%.
Clicking on &quot;Print&quot; at the top of the page prints the
composed page using the browser's printing method.

<p></p>

<strong>Export and import</strong><br>
When clicking on &quot;export&quot; the current content of the session
(including settings, macros, constraints, queries, and history) is
packed into a wITIP file, which can be saved for future use.
To restore the saved content, click on &quot;import&quot; and specify the
saved wITIP file. The created wITIP file is bound to both the session 
ID and the hosting web server: you cannot open an exported content using
different ID or different wITIP web server.
<b>Warning:</b>
After a successful import the previous content is 
irrecoverably lost. Please consider exporting the session first.

<p></p>
<strong>Save and execute: bulk input</strong><br>
To download an (editable) command file re-creating all macros, constraints,
and the last query, click on &quot;save&quot;. To execute commands in such
a file, click on &quot;execute&quot;. The command file has strict syntax,
size limits (both for line length and number of lines), and execution
stops at the first error. For syntax consult the command file created when
clicking on &quot;save&quot;.

<p></p>
PRINTING
#####################################################################
# EXPORT / IMPORT
    render_block($session,"quit","Quit wITIP",<<QUITTING);
Simply close the browser's window when you finished working on wITIP.
To switch to another session click on the &quot;change&quot; button 
under the &quot;session&quot; tab. It redirects to the wITIP login page
where you specify the new session ID you wish to work with.

<br>
There is no need to save your work. When you open a wITIP session,
the latest content is automatically restored.

<p></p>
QUITTING
#####################################################################
# METHOD
    render_block($session,"method","Under the hood: how wITIP works?",<<METHOD);
wITIP transforms the question on the validity of the entered query
into a satisfiability question of an LP problem.

<br>

First, the query is transformed into the following question: is a certain
linear combination of entropies equal to, or &ge; than zero?  When the
question asks for equality, it is further split into whether it is &ge; 0,
and whether its negation is also &le; 0.  Thus the enquiry is transformed to the
question (or to two questions) of the form

<div class="indent">
  <b>e</b> &ge; 0,
</div>
where <b>e</b> is a linear combination of entropies.

<br>

In the next step all L%var%random variables% occurring in <b>e</b> are
collected; denote this collection by S%V%.  Then the set of all <i>basic
Shannon inequalities</i> for all subsets of variables from S%V% is
generated.  This set implies all inequalities which
state that the entropy increases and is submodular:

<div class="indent">
  S%H(B)-H(A) &ge; 0% <br>
  &nbsp; &nbsp; where S%A% is a subset of S%B% which is a subset of
                 S%V%; moreover <br>
  S%H(A,C)+H(B,C)-H(C)-H(A,B,C) &ge; 0% <br>
  &nbsp; &nbsp; where S%A%, S%B% and S%C% are different subsets of S%V%. 
</div>

Then the LP solver is presented with the following solvability problem:

<div class="textindent" style="line-height: normal">
<i>Is there any non-negative linear combination of the provided basic Shannon
inequalities which gives</i> <b>e</b> &ge; 0 <i>?</i>
</div>
When there are enabled L%constr%constraints%, the basic Shannon
inequalities are supplemented by them: they can contribute
to the combination which finally yields the required inequality.
<p></p>
If the LP solver returns <i>yes</i>, then the result of the query is <span
class="restrue">true</span>; if the LP solver says <i>no</i>, then the
result is <span class="resfalse">false</span>. Consequently, the result
of the query is the answer to the question
<div class="textindent" style="line-height: normal">
<i>Does the query follow from the (basic) Shannon inequalities and
the given constraints?</i>
</div>
and <b>not</b> whether the query is a valid entropy inequality (or
equality) which holds for arbitrary collection of random variables
satisfying the stipulated constraints.

<p></p>
METHOD
#####################################################################
# HISTORY
    my $version=$session->getconf("version");
    render_block($session,"history","History",<<HISTORY);
<b>wITIP Version $version</b> is a web-based <b>I</b>nformation 
<b>T</b>heoretic <b>I</b>nequality <b>P</b>rover. The server-side 
program was written in  E%https://www.perl.org/%Perl% with the 
exception of the LP solver engine, which is a C frontend to glpk, the
E%https://www.gnu.org/software/glpk/%Gnu Linear Programming Kit%. 
You can find the source on E%https://github.com/lcsirmaz/witip%GitHub%.
<p></p>
The E%http://user-www.ie.cuhk.edu.hk/~ITIP%original ITIP software%
was developed by <i>Raymond W. Yeung</i> and <i>Ying-On Yan</i>, 
and runs under MATLAB. The stand-alone version 
E%http://xitip.epfl.ch%Xitip% has a graphical interface
and runs both in Windows and Linux.
<br>
The command-line version
E%https://github.com/lcsirmaz/minitip%minitip% uses the same
LP solver engine, and is written in 
E%https://en.wikipedia.org/wiki/C_(programming_language)%C% 
exclusively. There are several common features in wITIP and minitip.
<p></p>
HISTORY
#####################################################################
# COPYRIGHT
    render_block($session,"copyright","Author",<<COPYRIGHT);
wITIP is a free, open-source software available at
E%https://github.com/lcsirmaz/witip%github%. You may redistribute it and/or
modify under the terms of the 
E%http://www.gnu.org/licenses/gpl.html%GNU General Public License (GPL)% 
as published by the Free Software Foundation.
<br>
There is ABSOLUTELY NO WARRANTY, use at your own risk.
<br>
Copyright &copy; 2017-2024 Laszlo Csirmaz, UTIA, Prague
<p></p>
COPYRIGHT
    print "</div><!-- leftblock -->\n",
      "</td></tr></tbody></table>\n";
    print "</div><!-- main -->\n";

    wHtml::html_tail();
}

1;
