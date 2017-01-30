/* History javascript routines 
*
* This code is part of wITIP (a web based Information Theoretic Prover)
*
* Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
* This program is free, open-source software. You may redistribute it
* and/or modify under the terms of the GNU General Public License (GPL).
* There is ABSOLUTELY NO WARRANTY, use at your own risk.
*/

// the history, load history
// uses wi_autoResize(dom), wi_setCaret(dom,pos) 
var witipHistory= ['',''];
var witipHistoryLoaded=0;
function wi_requestHistory (what,ssid){
   new Ajax.Request ( witipBaseURL+'/history.txt', {
      method: 'get',
      parameters: {
          SSID:    ssid,
          what:    what,
          randomv: new Date().getTime() },
      onSuccess: function(x){
          var old0=witipHistory[0];
          witipHistory=x.responseText.split('\n');
          witipHistory.pop(); // get rid of the last empty line 
          witipHistory[0]=old0;
          witipHistoryLoaded=1;
          },
      onFailure: function(x){ // do nothing
// alert('failed...url='+witipBaseURL);
          }
   });
}
var witipHistoryPointer=0;
function wi_resetHistory() {
    witipHistoryPointer=0;
}
function wi_historyUp(itemid){
    if(!witipHistoryLoaded) return;
    var item=document.getElementById(itemid);
    if(witipHistoryPointer==0){
        witipHistory[0]=item.value;
    }
    witipHistoryPointer++;
    if(witipHistoryPointer>=witipHistory.length){
         // out of history
         witipHistoryPointer--;
         return;
    }
    item.value=witipHistory[witipHistoryPointer];
    wi_autoResize(item); item.focus();
    wi_setCaret(item,item.value.length);
}
function wi_historyDown(itemid) {
    if(witipHistoryPointer<=0) return;
    witipHistoryPointer--;
    var item=document.getElementById(itemid);
    item.value=witipHistory[witipHistoryPointer];
    wi_autoResize(item); item.focus();
    wi_setCaret(item,item.value.length);
}
function wi_addtoHistory(content) {
    if(witipHistoryPointer!=0) return;
    witipHistoryPointer++;
    witipHistory[0]=content;
}

