/* ConstrPage javascript routines 
*
* This code is part of wITIP (a web based Information Theoretic Prover)
*
* Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
* This program is free, open-source software. You may redistribute it
* and/or modify under the terms of the GNU General Public License (GPL).
* There is ABSOLUTELY NO WARRANTY, use at your own risk.
*/

// onload procedure: uncheck all ticks, resize the edit field,
// set focus and caret; scroll down the constraint list
// request history
function wi_initPage(){
   // set all ticks to the original value
   wi_resetDel();
   var inp=document.getElementById('constr_input');
   wi_autoResize(inp); inp.focus();
   wi_setCaret(inp,inp.value.length);
   var tble=document.getElementById('id-contable');
   var i=tble.rows.length;
   if(i>=2) tble.rows[i-1].scrollIntoView(true);
   wi_requestHistory('cons',document.getElementById('SSID').value);
}
// restore "use" and "delete" checkboxes
function wi_restoreCheckBoxes(){
   var item,item2;
   for(var i=1,item=document.getElementById('condel_1'); item;
       i++,item=document.getElementById('condel_'+i)){
      item.removeAttribute('disabled');
      item.checked=false;
      item2=document.getElementById('conused_'+i);
      item2.checked=witipConstrUsed[i-1]!=0;
      item2.removeAttribute('disabled');
      wi_setUsedClass(item2);
   }
}
// set item class to "conline-(un)used"
function wi_setUsedClass(item){
    var idx=item.id.split('_')[1];
    document.getElementById('con_'+idx+'_0').className = 
       'conline-'+(item.checked?'':'un')+'used';
}
// onchange: use constr checkbox changed
function wi_conUsedChanged(item){
    wi_setUsedClass(item);
    if((witipAllDisabled & 2)!=0) return;
    witipAllDisabled |= 2;
    // disable delete checkboxes
    var item;
    for( var i=1,item=document.getElementById('condel_1'); item;
       i++,item=document.getElementById('condel_'+i)){
       item.setAttribute('disabled',true);
    }
    document.getElementById('id-deleteall').style.visibility='hidden';
    document.getElementById('id-deletemarked').value='save changes';
    document.getElementById('delmarked').style.visibility='visible';
}
// onchange: delete checkbox value changed
function wi_conDelete(item){
    if(!item.checked) return;
    if((witipAllDisabled & 1)!=0) return;
    witipAllDisabled |= 1;
   // disable use checkboxes
    var item;
    for( var i=1,item=document.getElementById('conused_1'); item;
       i++,item=document.getElementById('conused_'+i)){
       item.setAttribute('disabled',true);
    }
    document.getElementById('id-deleteall').style.visibility='visible';
    document.getElementById('id-deletemarked').value='delete marked constraints';
    document.getElementById('delmarked').style.visibility='visible';
 }
// button "cancel" has been hit
function wi_resetDel(){
    document.getElementById('id-deleteall').style.visibility='hidden';
    document.getElementById('delmarked').style.visibility='hidden';
    witipAllDisabled &= ~3;
    wi_restoreCheckBoxes();
    return false;
}
//button "deletemarked" pushed
function wi_conDeleteMarked(){
    return true;
}
// button "deleteall" pushed
function wi_deleteAll(){
  var item;
  for(var i=1,item=document.getElementById('condel_1'); item;
    i++,item=document.getElementById('condel_'+i)){
        item.checked=true;
    }
    if(!confirm('You are going to delete all constraints.\nProceed?'))
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
    var txt=item.getAttribute('data-con');
    var target=document.getElementById('constr_input');
    wi_addtoHistory(target.value);
    target.value=txt;
    target.focus();
    wi_setCaret(target,txt.length);
    wi_autoResize(target);
    document.getElementById('constr_errmsg').innerHTML='';
    document.getElementById('constr_auxmsg').innerHTML='';
}
var wi_lastHeight=0; // automatically increases height, does not decrease.
function wi_autoResize(item){
  if(item.scrollHeight-wi_lastHeight>4){
     item.style.height=item.scrollTop+item.scrollHeight+'px';
     wi_lastHeight=item.scrollHeight;
     document.getElementById('constr_shadow').style.height=wi_lastHeight+'px';
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
// Enter or "add constraint" button
function wi_addConstraint(){
    if(witipAllDisabled) return false;
    // launch ajax request
    witipAllDisabled |= 4;
    new Ajax.Request( witipBaseURL+'/chkconstr.txt', {
        method: 'get',
        parameters: {
           SSID: document.getElementById('SSID').value,
           text: document.getElementById('constr_input').value,
           randomv: new Date().getTime()
        },
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
               document.getElementById('constr_shadow').value=posstr;
               document.getElementById('constr_errmsg').innerHTML=wi_htmlize(errmsg);
               document.getElementById('constr_auxmsg').innerHTML=wi_htmlize(auxmsg);
               wi_setCaret(document.getElementById('constr_input'),errpos);
            } else { // OK, relaunch the page
               document.getElementById('constr_input').value='';
               document.getElementById('form-main').submit();
            }
            witipAllDisabled &= ~4;
        },
        onFailure: function(x){
// alert("ajax failed...");
          witipAllDisabled &= ~4;
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
    document.getElementById('constr_shadow').value='';
    // handle keys
    if(key==40 || key=='ArrowDown' || key=='Down'){ // down
        wi_killEvent(event);
        document.getElementById('constr_errmsg').innerHTML='';
        document.getElementById('constr_auxmsg').innerHTML='';
        wi_historyDown('constr_input');
        return false;
    } else if(key==38 || key=='ArrowUp' || key=='Up'){ // up
        wi_killEvent(event);
        document.getElementById('constr_errmsg').innerHTML='';
        document.getElementById('constr_auxmsg').innerHTML='';
        wi_historyUp('constr_input');
        return false;
    } else if(key==13 || key=='Enter'){ // enter
        wi_killEvent(event);
        wi_addConstraint();
        return false;
    }
    wi_resetHistory(); // some other keyhit
    return true;
}


