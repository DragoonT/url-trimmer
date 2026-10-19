const fs=require('fs'),vm=require('vm'),assert=require('assert');
let stored={},loggedIn=false,posts=[],removed=[],cookieReads=0;
const noop={addListener(){}};
const scope={chrome:{storage:{session:{get:async()=>({connections:structuredClone(stored)}),set:async x=>{stored=structuredClone(x.connections);}}},tabs:{create:async()=>({id:701}),get:async()=>({url:'https://www.youtube.com/',status:'complete'}),remove:async id=>removed.push(id),sendMessage:async()=>{},onUpdated:noop,onRemoved:noop},cookies:{getAllCookieStores:async()=>[{id:'store',tabIds:[701]}],getAll:async filters=>{assert.equal(filters.domain,'youtube.com');assert.equal(filters.storeId,'store');cookieReads++;return [{domain:'.youtube.com',name:'SID',value:'test-only',path:'/',hostOnly:false}];},onChanged:noop},scripting:{executeScript:async()=>[{result:loggedIn}]},alarms:{create:async()=>{},clear:async()=>{},onAlarm:noop},runtime:{onMessage:noop}},URL,Date,Set,Promise,JSON,Error,fetch:async(url,options)=>{if(options){posts.push(JSON.parse(options.body));return {ok:true,json:async()=>({})};}return {ok:true,json:async()=>({platform:'youtube',url:'https://www.youtube.com/',domains:['youtube.com'],markers:[]})};}};
vm.createContext(scope);vm.runInContext(fs.readFileSync('browser-extension/background.js','utf8'),scope);
(async()=>{
 const token='a'.repeat(43);await scope.begin(token,{tab:{url:'http://127.0.0.1:8765/connect.html',id:501}});
 await scope.check(stored[token]);assert.equal(posts.length,0);assert.equal(removed.length,0);
 loggedIn=true;await scope.check(stored[token]);assert.equal(posts.length,1);assert.equal(posts[0].verified,true);assert.deepEqual(removed,[701,501]);assert.deepEqual(stored,{});
 await assert.rejects(scope.begin(token,{tab:{url:'https://untrusted.example/connect.html',id:999}}));
 assert.equal(posts.length,1);console.log('Extension waits for YouTube login, reads only chosen-platform cookies, uses correct store, and closes only owned tabs; foreign origins rejected');
})().catch(error=>{console.error(error);process.exitCode=1;});
