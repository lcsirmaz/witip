####################
## wPrintPage.pm
####################
##
## Printable version of the current session
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wPrintPage;

use wHtml;
use wUtils;
use strict; 

################################################################

# hide block, this is not printed
sub hideit {
    my($buttons)=@_;
## HTML code
## <div class="hideit">
##  <span class="hidebutton" onclick="hideall('macrounroll');">
##    unrolled </span>
##  <span class="hidebutton" onclick="hideall('allmacro');">
##    macros </span>
## </div>
    print "<div class=\"hideit\"> Show / hide \n";
    foreach my $b(@$buttons){
        print "<span class=\"hidebutton\"",
         " onclick=\"wi_hideit(this,",$b->[0],");\"",
         " title=\"",$b->[2],"\"> ",$b->[1], " </span>\n";
    }
    print "</div>\n";
}

# order macros by name, then by argument number, then
# by argument type.
sub _cmpmacros {
    my($a,$b)=@_;
    if($a->{name} ne $b->{name}){
        return $a->{name} cmp $b->{name};
    }
    if($a->{argno} != $b->{argno}){
        return $a->{argno} <=> $b->{argno};
    }
    return $a->{septype} <=> $b->{septype};
}

# render macros
sub macros_table {
## HTML code
## <div class="block">
##  SHOW/HIDE block
##  <div id="mactable_1" data-mask="1" class="container">
##  <div class="subtitle">TITLE</div>
##  <table><tbody>
##   <tr id="macrolin_##" data-mask="1">
##     <td class="origline/unrline">~</td>
##     <td class="code">macro text</td>
##  </tr>
## </tbody></table></div></div>
    my($session)=@_;
    use wParser;
    my $parser=new wParser($session);
    print "<div class=\"block\">\n";
    hideit([
       ["'mactable',1","all macros","hide/show all macros"],
       ["'macrolin',1","original","hide/show original text"],
       ["'macrolin',2","unrolled","hide/show unrolled form"],
    ]);
    print "<div id=\"mactable_1\" data-mask=\"1\" class=\"container\">\n";
    print "<div class=\"subtitle\" contenteditable=\"true\">Macros</div>\n";
    print "<table class=\"mactable\"><tbody>\n";
    my $macrocnt=0;
    my $macrolist=wUtils::read_user_macros($session);
    foreach my $macro ( sort {_cmpmacros($a,$b)} @$macrolist ){
        next if($macro->{std});
        $macrocnt++;
        print "<tr id=\"macrolin_$macrocnt\" data-mask=\"1\">\n",
          "<td class=\"origline\">",$session->{origText},"</td>\n",
          "<td class=\"code\">",$macro->{raw},"</td></tr>\n";
        $macrocnt++;
        print "<tr id=\"macrolin_$macrocnt\" data-mask=\"2\">\n",
          "<td class=\"unrline\">",$session->{unrollText},"</td>\n",
          "<td class=\"code\">",$parser->print_macro($macro),"</td></tr>\n";
    }
    print "</tbody></table></div></div>\n";
}

# render a constraint line
sub constr_line {
    my($count,$orig,$mask,$class,$text)=@_;
    print "<tr id=\"conline_$count\" data-mask=\"$mask\">\n";
    print "<td class=\"$orig</td>\n";
    print "<td class=\"$class</td>\n";
    print "<td class=\"code\">",$text,"</td></tr>\n";
}

# render constraints
sub constr_table {
## HTML code
## <div class="block">
##   SHOW/HIDE block
##  <div id="contable_1" data-mask="1" class="container">
##  <div class="subtitle>TITLE</div>
##  <table class="contable"><tbody>
##    <tr id="conline_##" data-mask="3">
##      <td class="not_/enabled"> -/+ </td>
##      <td class="origline/unrline"> ~ </td>
##      <td class="code"> text </td>
##    </tr>
## </tbody></table></div></div>
    my($session)=@_;
    use wParser;
    my $parser=new wParser($session);
    print "<div class=\"block\">\n";
    hideit([
       ["'contable',1","all constraints","hide/show all constraints"],
       ["'conline',1" ,"disabled","hide/show not enabled constraints"],
       ["'conline',2" ,"original","hide/show original text"],
       ["'conline',4" ,"unrolled","hide/show unrolled form"],
    ]);
    print "<div id=\"contable_1\" data-mask=\"1\" class=\"container\">";
    print "<div class=\"subtitle\" contenteditable=\"true\">Constraints</div>\n";
    print "<table class=\"contable\"><tbody>\n";
    my $ccount=0;
    my $constrlist=wUtils::read_user_constraints($session);
    $parser->load_id_table(); # loads id table
    foreach my $ctr (@$constrlist){
       # mask= 1: skip, 2: original, 4: unrolled
       my $mask=0; my $class="enabled\">&#x2713;"; # +
       if($ctr->{skip}){
           $mask=1; $class="not-enabled\">&#xd7;"; # &#2715;
       }
       my $oline="origline\">".$session->{origText};
       my $uline="unrline\">".$session->{unrollText};
       # original
       $ccount++;
       constr_line($ccount,$oline,$mask|2,$class,$ctr->{raw});
       # unrolled
       if($ctr->{rel} eq "markov"){
          foreach my $e(@{$ctr->{text}}){
             $ccount++;
             constr_line($ccount,$uline,$mask|4,$class,
               $parser->print_expression($e)."=0");
          }
       } else {
          $ccount++;
          constr_line($ccount,$uline,$mask|4,$class,
            $parser->print_expression($ctr->{text}).$ctr->{rel}."0");
       }
    }
    print "</tbody></table></div></div>\n";
}

# render a query line
sub expr_line {
    my($cnt,$mask,$res,$const,$expr)=@_;
    print "<tr id=\"expline_$cnt\" data-mask=\"$mask\"><td class=\"result\">",
      ("","","","","timeout","failed","TRUE","FALSE","only &ge;","only &le;")[$res],
      "</td><td class=\"withc\">",
      ($const?" ":"C"),"</td>\n",
      "<td class=\"code\">$expr</td></tr>\n";
}

# render queries
sub query_table {
## HtML code
## <div class="block">
##  SHOW/HIDE block
##  <div id="exptable_1" data-mask="1" class="container">
##  <div class="subtitle">TITLE</div>
##  <table class="exptable"><tbody>
##    <tr id="expline_##" data-mask="1">
##     <td class=\"result\">result</td>
##     <td class=\"withc\"> with/without constraints </td>
##     <td class="code"> text </td>
##    </tr>
##  </tbody></table></div></div>
    my ($session) = @_;
    print "<div class=\"block\">\n";
    hideit([
      ["'exptable',1","all queries","hide/show all queries"],
      ["'expline',1","unroll","hide/show unroll queries"],
      ["'expline',2","check","hide/show relations"],
    ]);
    print "<div id=\"exptable_1\" data-mask=\"1\" class=\"container\">\n";
    print "<div class=\"subtitle\" contenteditable=\"true\">Queries</div>\n";
    print "<table class=\"exptable\"><tbody>\n";
    my $expcnt=0;
    use wMainPage;
    my $lines=wMainPage::parse_expr_history($session) -> {hist};
##    my $lines=$hist->{hist};
    foreach my $expr (@$lines){
       ## [ type, label, standalone, text ]
       my ($type,$text)=($expr->[0],$expr->[3]);
       if($type==2){ # unroll
           $text =~ s/\+\+\+(.*)$//; my $res=$1;
           $expcnt++; expr_line($expcnt,1,0,1,$text);
           $expcnt++; expr_line($expcnt,1,0,1,$res);
       } elsif($type>=4 && $type<=9){ # timeout,failed,true,false,>=,<=
           $expcnt++; expr_line($expcnt,2,$type,$expr->[2],$text);
       }
    }
    print "</tbody></table></div></div>\n";
}

sub Page {
    my($session)=@_;
    wHtml::plain_header($session,"wITIP ".wUtils::htmlescape($session->{SSID}), {
     lcss => "printing",
     javascript => "
function wi_hideit(box,id,mask){
   if(!box.getAttribute('data-clicked')){
      box.setAttribute('data-clicked',1);
      box.style.backgroundColor='#cecece';
   } else {
      box.setAttribute('data-clicked','');
      box.style.backgroundColor='#f8f8f8';
   }
   var item;
   for( var i=1,item=document.getElementById(id+'_1'); item;
        i++,item=document.getElementById(id+'_'+i)){
       if((parseInt(item.getAttribute('data-mask'),10)&mask)!=0){
          if(!item.hasAttribute('data-state')){
             item.setAttribute('data-state','0');
             item.setAttribute('data-disp',item.style.display);
          }
          var st=parseInt(item.getAttribute('data-state'),10);
          // 0 visible, otherwise bits which block
          var newst = st ^ mask; // flip this bit
          item.setAttribute('data-state',''+newst);
          if(newst==0) 
             item.style.display=item.getAttribute('data-disp');
          else
             item.style.display='none';
       }
   }
}
",
    });
    print "<div class=\"explanation\">
    Use this page to choose what to print. You can edit the main title, and
    the title of each section. When you are done, click on
    <a href=\"javascript:window.print();\">Print</a>.
    </div>\n";
    # main title
    print "<div class=\"spacer\"> </div>\n";
    my($sec,$min,$hour,$day,$mon)=localtime(time);
    my $date=sprintf("%s %d, %d:%02d:%02d",
          qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon],
          $day,$hour,$min,$sec);
    print "<div class=\"maintitle\" contenteditable=\"true\">Content of wITIP session &raquo;",
      wUtils::htmlescape($session->{SSID}),"&laquo; as of $date </div>\n";
    print "<div class=\"spacer\"> </div>\n";
    # original / asis texts
    $session->{origText}="";
    $session->{unrollText}="~";
    # macros
    macros_table($session);
    print "<div class=\"spacer\"> </div>\n";
    # constraints
    constr_table($session);
    print "<div class=\"spacer\"> </div>\n";
    # queries
    query_table($session);
    print "<div class=\"spacer\"> </div>\n";
    # tail
    wHtml::html_tail();
}

1;


