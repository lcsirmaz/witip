/* MacroPage javascript routines 
*
* This code is part of wITIP (a web based Information Theoretic Prover)
*
* Copyright 2017-2024 Laszlo Csirmaz, UTIA, Prague
* This program is free, open-source software. You may redistribute it
* and/or modify under the terms of the GNU General Public License (GPL).
* There is ABSOLUTELY NO WARRANTY, use at your own risk.
*/

// onload procedure: uncheck all ticks, resize the edit field, 
// set focus and caret; scroll down the macro list
// request the history
function wi_initPage(){
    // set all ticks to unchecked
    var item;
    for(var i=1,item=document.getElementById('mdel_1'); item; 
       i++,item=document.getElementById('mdel_'+i)){
      item.checked=false;
    }
    var inp=document.getElementById('macro_input');
    wi_autoResize(inp); inp.focus();
    wi_setCaret(inp,inp.value.length);
    var tble=document.getElementById('macrotable');
    var i=tble.rows.length;
    if(i>=2) tble.rows[i-1].scrollIntoView(true);
    wi_requestHistory('macro',document.getElementById('SSID').value);
}
// onchange delete checkbox value changed
function wi_macroDel(item){
    if(!item.checked){
       var ischecked=0,iit;
       for(var i=1,iit=document.getElementById('mdel_1'); iit;
          i++,iit=document.getElementById('mdel_'+i)) {
           if(iit.checked){ ischecked=1; }
       }
       if(ischecked) return;
       document.getElementById('delmarked').style.visibility='hidden';
       document.getElementById('id-cover').style.display='none';
       witipAltSubmit=null;
       witipAllDisabled &= ~1;
       return;
    }
    if((witipAllDisabled & 1)!=0) return;
    witipAllDisabled |= 1;
    witipAltSubmit='id-deletemarked';
    document.getElementById('delmarked').style.visibility='visible';
    document.getElementById('id-cover').style.display='block';
}
// button "cancel delete" pushed
function wi_resetDel(){
    document.getElementById('delmarked').style.visibility='hidden';
    document.getElementById('id-cover').style.display='none';
    witipAltSubmit=null;
    witipAllDisabled &= ~1;
    // set all ticks to unchecked
    var item;
    for(var i=1,item=document.getElementById('mdel_1'); item; 
       i++,item=document.getElementById('mdel_'+i)){
      item.checked=false;
    }
    return false;
}
// button "deletemarked" pushed
function wi_deleteMarkedMacros() {
    if(document.getElementById('goingto').value=='macros') return true;
    if(!confirm('Marked macro lines will be deleted.\nProceed?'))
        return false;
    return true;
}
// button "deleteall" pushed
function wi_deleteAll(){
    var item;
    for(var i=1,item=document.getElementById('mdel_1'); item;
       i++,item=document.getElementById('mdel_'+i)){
      item.checked=true;
    }
    if(!confirm('You are going to delete all macros.\nProceed?'))
          return false;
    return true;
}
// set caret in macro editing textarea
function wi_setCaret(item,pos){
    if('setSelectionRange' in item){
       item.focus();
       item.setSelectionRange(pos,pos);
    } else if('createTextRange' in item){ // IE
       var range=item.createTextRange();
       range.collapse(true);
       range.moveEnd('character',pos);
       range.moveStart('character',pos);
       range.select();
    }
}
// onclick a line in macro listing
function wi_copyLineToEdit(item){
    if(witipAllDisabled) return;
    var txt=item.getAttribute('data-macro');
    var target=document.getElementById('macro_input');
    wi_addtoHistory(target.value);
    target.value=txt;
    target.focus();
    wi_setCaret(target,txt.length);
    wi_autoResize(target);
    document.getElementById('macro_errmsg').innerHTML=
        'expanded (internal) form of this macro:';
    document.getElementById('macro_auxmsg').innerHTML=
        wi_htmlize(item.getAttribute('data-unrolled'));
}
var wi_lastHeight=0; // automatically increases height, does not decrease.
function wi_autoResize(item){
  if(item.scrollHeight-wi_lastHeight>4){
     item.style.height=item.scrollTop+item.scrollHeight+'px';
     wi_lastHeight=item.scrollHeight;
     document.getElementById('macro_shadow').style.height=wi_lastHeight+'px';
     document.getElementById('iddblinput').style.height=(wi_lastHeight+4)+'px';
  }
}
// replace <>"'
function wi_htmlize(str) {
    return str.replace(/&/g,"&amp;")
     .replace(/</g,"&lt;")
     .replace(/>/g,"&gt;")
     .replace(/"/g,"&quot;");
}
// Enter or button "add macro" pushed
function wi_addMacro(item){
    if(witipAllDisabled) return false;
    // launch ajax request
    witipAllDisabled |= 2;
    new Ajax.Request( witipBaseURL+'/chkmacro.txt', {
        method: 'get',
        parameters: {
            SSID:  document.getElementById('SSID').value,
            text:  document.getElementById('macro_input').value },
            randomv: new Date().getTime(),
        onSuccess: function(x){
            var r=x.responseText;
            if(r.substr(0,1) == '1'){ // error
                var errpos=parseInt(r.substr(2),10);
                var errmsg=r.substr(r.indexOf(',',2)+1);
                var iaux=errmsg.indexOf('+++');
                var auxmsg='';
                if(iaux>=0){
                   auxmsg=errmsg.substr(iaux+3);
                   errmsg=errmsg.substr(0,iaux);
                }
                var posstr='_';
                while(posstr.length<errpos) posstr += posstr;
                posstr=posstr.substr(0,errpos);
                document.getElementById('macro_shadow').value=posstr;
                document.getElementById('macro_errmsg').innerHTML=wi_htmlize(errmsg);
                document.getElementById('macro_auxmsg').innerHTML=wi_htmlize(auxmsg);
                wi_setCaret(document.getElementById('macro_input'),errpos);
            } else { // OK, relaunch the page
                document.getElementById('macro_input').value='';
                document.getElementById('form-main').submit();
            }
            witipAllDisabled &= ~2;
        },
        onFailure: function(x){
            // alert("ajax failed...");
            witipAllDisabled &= ~2;
        }
    });
    return false;
}
// kill a keyhit
function wi_killEvent(event){
    if(typeof event.stopPropagation !='undefined'){
       event.stopPropagation();
    } else { event.cancelBubble=true; }
    event.preventDefault();
}
function wi_editKey(event){
    if(!event) event=window.event;
    var key=event.key;
    if(!key) key=event.keyCode;
    if(!key) key=event.which;
    if(witipAllDisabled){
       if(key==9 || key=='Tab') return true;
       wi_killEvent(event);
       return false;
    }
    // clear error point indicator, if any
    document.getElementById('macro_shadow').value='';
    // handle keys
    if(key==40 || key=='ArrowDown' || key=='Down'){ // down
        wi_killEvent(event);
        document.getElementById('macro_errmsg').innerHTML='';
        document.getElementById('macro_auxmsg').innerHTML='';
        wi_historyDown('macro_input');
        return false;
    } else if(key==38 || key=='ArrowUp' || key=='Up'){ // up
        wi_killEvent(event);
        document.getElementById('macro_errmsg').innerHTML='';
        document.getElementById('macro_auxmsg').innerHTML='';
        wi_historyUp('macro_input');
        return false;
    } else if(key==13 || key=='Enter'){ // enter
        wi_killEvent(event);
        wi_addMacro(); 
        return false;
    }
    wi_resetHistory(); // some other keyhit
    return true;
}
