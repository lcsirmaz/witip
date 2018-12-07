/* MainPage javascript routines 
*
* This code is part of wITIP (a web based Information Theoretic Prover)
*
* Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
* This program is free, open-source software. You may redistribute it
* and/or modify under the terms of the GNU General Public License (GPL).
* There is ABSOLUTELY NO WARRANTY, use at your own risk.
*/

// onload procedure
var wi_HistLast=0;   // last id in resulttable
var wi_HistPointer=0;// where the pointer is set
function wi_initPage(){
    wi_resetDel(); // set all ticks to "unchecked"
    var inp=document.getElementById('expr_input');
    wi_autoResize(inp); inp.focus();
    wi_setCaret(inp,inp.value.length);
    var tble=document.getElementById('resulttable');
    var i=tble.rows.length;
    if(i>=2){ tble.rows[i-1].scrollIntoView(true);
       wi_HistLast=i;
       while(wi_HistLast>1 && !document.getElementById('histID_'+wi_HistLast)) wi_HistLast--;
    }
    wi_TimeId=setTimeout(wi_checkPending,1000);
}
// onchange: delete checkbox value changed
function wi_resDelete(item){
    if(!item.checked){ // are there checked items
       var ischecked=0,iit;
       for(var i=1,iit=document.getElementById('resdel_1'); iit;
          i++,iit=document.getElementById('resdel_'+i)) {
           if(iit.checked){ ischecked=1;}
       }
       if(ischecked){ return; }
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
// button "cancel" has been hit
function wi_resetDel(){
    document.getElementById('delmarked').style.visibility='hidden';
    document.getElementById('id-cover').style.display='none';
    witipAltSubmit=null;
    witipAllDisabled &= ~1;
    var item;
    for(var i=1,item=document.getElementById('resdel_1'); item;
        i++,item=document.getElementById('resdel_'+i)) {
      item.checked=false;
    }
    return false;
}
// button "delete marked lines" was hit
function wi_deleteMarkedLines(){
    if(document.getElementById('goingto').value=='check') return true;
    if(!confirm('Marked result lines will be deleted.\nProceed?'))
        return false;
    return true;
}
// button "deleteall" was hit
function wi_deleteAll(){
    var item;
    for(var i=1,item=document.getElementById('resdel_1'); item;
      i++,item=document.getElementById('resdel_'+i)){
        item.checked=true;
    }
    if(!confirm('You are going to delete all result lines. They will be irrecoverably lost.\nProceed?'))
      return false;
    return true;
}
// set caret in editing textarea
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
var wi_lastHeight=0; // automatically increases height, does not decrease.
function wi_autoResize(item){
  if(item.scrollHeight-wi_lastHeight>4){
     item.style.height=item.scrollTop+item.scrollHeight+'px';
     wi_lastHeight=item.scrollHeight;
     document.getElementById('expr_shadow').style.height=wi_lastHeight+'px';
     document.getElementById('iddblinput').style.height=(wi_lastHeight+4)+'px';
  }
}
// replace <>"
function htmlize(str) {
    return str.replace(/&/g,"&amp;")
     .replace(/</g,"&lt;")
     .replace(/>/g,"&gt;")
     .replace(/"/g,"&quot;");
}
// history handling
// wi_HistLast:    the maximal id in 'resulttable'
// wi_HistPointer: 0 if none, otherwise an index 1 .. wi_HistLast
var wi_HistZeroLine='';
function wi_historyUp(){
    if(wi_HistLast<2) return;
    var item=document.getElementById('expr_input');
    if(wi_HistPointer==0){
        wi_HistZeroLine=item.value; // save it
        wi_HistPointer=wi_HistLast+1;
    }
    do {wi_HistPointer--;
        if(wi_HistPointer<=0){ wi_HistPointer=1; return; }
        var from=document.getElementById('histID_'+wi_HistPointer);
        if(!from) return;
        if(item.value != from.getAttribute('data-expr')){
            item.value=from.getAttribute('data-expr');
            wi_setCaret(item,item.value.length);
            wi_autoResize(item); item.focus();
            return;
        }
    } while (true);
}
function wi_historyDown(){
    if(wi_HistLast<2 || wi_HistPointer==0) return;
    var txt;
    var item=document.getElementById('expr_input');
    do {wi_HistPointer++; if(wi_HistPointer>wi_HistLast){
           wi_HistPointer=0; txt=wi_HistZeroLine;
        } else {
           txt=document.getElementById('histID_'+wi_HistPointer).
               getAttribute('data-expr');
        }
        if(wi_HistPointer==0 || item.value!= txt){
            item.value=txt;
            wi_setCaret(item,txt.length);
            wi_autoResize(item); item.focus();
            return;
        }
    } while(true);
}
// onclick a line in the listing
function wi_copyLineToEdit(item){
    if(witipAllDisabled) return;
    var txt=item.getAttribute('data-expr');
    var target=document.getElementById('expr_input');
    var index=item.id.replace(/^histID_/,'');
    if(wi_HistPointer==0) wi_HistZeroLine=target.value;
    wi_HistPointer=index;
    target.value=txt;
    target.focus();
    wi_setCaret(target,txt.length);
    wi_autoResize(target);
}
// check class if defined
function wi_setClass(id,cname){
    var item=document.getElementById(id);
    if(item) item.className=cname;
}
// check entered expression
// exprtype:    0   1   2      3          4        5        6      7
var witipCDArr=['','','zap','waiting','timeout','failed','true','false',
//        8        9        10       11
       'onlyge','onlyle','eqzero','gezero'];
// return the focus to the input field
function wi_checkInput(){ // 1: with, 0: without constraints
    if(witipAllDisabled) return false;
    var how=document.getElementById('id-chkwith').checked ? 1 : 0;
    witipAllDisabled |= 4;
    new Ajax.Request( witipBaseURL+'/chkexpr.txt', {
       method: 'get',
       parameters: {
          SSID: document.getElementById('SSID').value,
          text: document.getElementById('expr_input').value,
          cstr: how, // with or without constraints
          randomv: new Date().getTime()
       },
       onSuccess: function(x){
          var r=x.responseText.replace(/[\n\r]/g,'');
          var code=parseInt(r,10);
          if(code==1){ // error
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
             document.getElementById('expr_shadow').value=posstr;
             document.getElementById('expr_errmsg').innerHTML=htmlize(errmsg);
             document.getElementById('expr_auxmsg').innerHTML=htmlize(auxmsg);
             wi_setCaret(document.getElementById('expr_input'),errpos);
          } else { // no error, add expr:input with the result to the table
              var label=parseInt(r.substr(code<9?2:3),10);
              var auxmsg='', constr=how;
              if(code==2){
                  auxmsg=r.substr(r.indexOf(',',2)+1);
                  constr=0;
              }
              var expr=document.getElementById('expr_input').value;
              // waiting/failed/true/false/onlyge/onlyle/zap/eqzero/gezero
              wi_addline(label,witipCDArr[code],constr,expr,auxmsg);
              // clean up all
              document.getElementById('expr_shadow').value='';
              document.getElementById('expr_errmsg').innerHTML='';
              document.getElementById('expr_auxmsg').innerHTML='';
              document.getElementById('expr_input').value='';
              if(code==3) wi_addLabel(label); // ask about the result
              // indicate change
              document.getElementById('wi_modified').innerHTML='*';
          }
          witipAllDisabled &= ~4;
       },
       onFailure: function(x){
          witipAllDisabled &= ~4;
       }
    });
    document.getElementById('expr_input').focus();
    wi_HistPointer=0; // reset Up/Down keys
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
    document.getElementById('expr_shadow').value='';
    // handle keys
    if(key==40 || key=='ArrowDown' || key=='Down'){ // down
        wi_killEvent(event);
        document.getElementById('expr_errmsg').innerHTML='';
        document.getElementById('expr_auxmsg').innerHTML='';
        wi_historyDown();
        return false;
    } else if(key==38 || key=='ArrowUp' || key=='Up'){ // up
        wi_killEvent(event);
        document.getElementById('expr_errmsg').innerHTML='';
        document.getElementById('expr_auxmsg').innerHTML='';
        wi_historyUp();
        return false;
    } else if(key==13 || key=='Enter'){ // enter
        wi_killEvent(event);
        wi_checkInput();
        return false;
    }
    wi_HistPointer=0; // some other keyhit, reset history
    return true;
}
// check pending requests
// wi_pendingLabels[] contains pending labels
var wi_timeId=0;         // timer
var wi_waitingPending=0; // waiting for ajax response
var wi_waitDelay=0;      // delay for next request
// schedule next ajax request
function wi_scheduleNext(){
  wi_waitDelay += wi_waitDelay;
  if(wi_waitDelay>60) wi_waitDelay=60;
  else if(wi_waitDelay>30) wi_waitDelay=30;
  else if(wi_waitDelay<1) wi_waitDelay=1;
  wi_timeId=setTimeout(wi_checkPending,1000*wi_waitDelay);
}
// add new request
function wi_addLabel(label){
  if(wi_timeId!=0) clearTimeout(wi_timeID);
  wi_waitDelay=0; // reset delay
  var addit=1;

  for (var i=0;i<wi_pendingLabels.length;i++){
    if(wi_pendingLabels[i]==0 && addit!=0){
       addit=0; wi_pendingLabels[i]=label;
    }
  }
  if(addit) wi_pendingLabels.push(label);
  wi_checkPending();
}
// send the ajax request and process the result
function wi_checkPending(){
  wi_timeID=0; // timer is not valid anymore
  if(wi_waitingPending!=0) return;
  // create request
  var req='';
  for (var i=0;i<wi_pendingLabels.length;i++){
        if(wi_pendingLabels[i]!=0) req += ','+wi_pendingLabels[i];
  }
  if(req == '' ) return; // no request
  wi_waitingPending=1;   // wait until the result arrives
  new Ajax.Request( witipBaseURL+'/chkpending.txt', {
        method: 'get',
        parameters: {
            SSID: document.getElementById('SSID').value,
            what: req,
            randomv: new Date().getTime()
        },
        onSuccess: function(x){
          wi_waitingPending=0;
          var resa=x.responseText.split('\n');
          // <label>,<result>
          for(var i=0;i<resa.length;i++){
              var sp=resa[i].replace(/[\n\r]/g,'').match(/^(\d+),([a-z]*)$/);
              if(sp!=null) wi_replaceResult(sp[1],sp[2]);
          }
          wi_scheduleNext();
        },
        onFailure: function(x){
           wi_waitingPending=0;
           wi_scheduleNext();
        }
    });
}
// wi_addline(hist,result,constr,line,aux)
//   hist: history number, should be unique, not used before
//   result: string, one of [waiting|failed|true|false|onlyge|onlyle|zap]
//   constr: 0 - without constraints, 1 - with constraints
//   line:   the line to be added
//   aux:    if not empty, the result line for a zap result
// DOM structure:
//  <tr class="resultline" id="res_###_0">
//      <td class="rescode" id="res_###_1"><NODE id="proto_{result}"></td>
//      <td class="constraint"><NODE id="proto_[constr|noconstr]"></td>
//      <td class="query1"><NODE id="proto_code"></td>
//  </tr>
// when there is an aux line, add
//  <tr class="auxline">
//      <td class="skip"></td>
//      <td class="skip"></td>
//      <td class="query2"><NODE id="proto_aux"></td>
//  </tr>
//
var tmpId=5; // tmp ID for cloned nodes
// label: integer (label)
// result: waiting/failed/true/false/onlyge/onlyle/zap/eqzero/gezero/
// constr: 0: with no costraints, 1: with constraints
// line, aux: content of line (aux)
function wi_addline(label,result,constr,line,aux){
   var tble=document.getElementById('resulttable');
   var newrow=tble.insertRow(-1);
   newrow.id='res_'+label+'_0'; newrow.className='resultline';
   // delete column
   var col=newrow.insertCell(0); col.className='resdel';
   col.title='delete this query';
   var idx='resdel_'+(wi_HistLast+1);
   var newdiv=document.createElement('div'); newdiv.className='resinnerdel';
   col.appendChild(newdiv);
   var colcont=document.getElementById('proto_delete').cloneNode(1);
   colcont.id=idx; colcont.name='resdel_'+label;
   newdiv.appendChild(colcont);
   colcont=document.createElement('label'); colcont.setAttribute('for',idx);
   newdiv.appendChild(colcont);
   // result column
   col=newrow.insertCell(1);
   col.id='res_'+label+'_1'; col.className='rescode';
   colcont=document.getElementById('proto_'+result).cloneNode(1);
   colcont.id='tmpId_'+tmpId; tmpId++;
   col.appendChild(colcont);
   // with/without constraints
   col=newrow.insertCell(2); col.className='constraint';
   colcont=document.getElementById('proto_'+(constr?'constr':'noconstr')).cloneNode(1);
   colcont.id='tmpId_'+tmpId; tmpId++;
   col.appendChild(colcont);
   // code
   col=newrow.insertCell(3); col.className='query1';
   colcont=document.getElementById('proto_code').cloneNode(1);
   colcont.setAttribute('data-expr',line);
   wi_HistLast++;
   colcont.id='histID_'+wi_HistLast;
   colcont.appendChild(document.createTextNode(line));
   col.appendChild(colcont);
   // aux line
   if(aux){
       newrow=tble.insertRow(-1); newrow.className='auxline';
       col=newrow.insertCell(0); col.className='skip';
       col=newrow.insertCell(1); col.className='skip';
       col=newrow.insertCell(2); col.className='skip';
       col=newrow.insertCell(3); col.className='query2';
       colcont=document.getElementById('proto_auxcode').cloneNode(1);
       colcont.id='tmpId_'+tmpId; tmpId++;
       colcont.appendChild(document.createTextNode(aux));
       col.appendChild(colcont)
   }
   // scroll to show
   newrow.scrollIntoView(true);
}
// replace result field
//  label:  label
//  result: one of [timeout|failed|true|false|onlyge|onlyle|eqzero|gezero]
function wi_replaceResult(label,result){
    if(label==0) return;
    for(var i=0;i<wi_pendingLabels.length;i++){
        if(label == wi_pendingLabels[i]) wi_pendingLabels[i]=0;
    }
    var col=document.getElementById('res_'+label+'_1');
    if(!col) return; // not found
    var colcont=document.getElementById('proto_'+result).cloneNode(1);
    colcont.id='tmpId_'+tmpId; tmpId++;
    col.replaceChild(colcont,col.firstChild);
}



