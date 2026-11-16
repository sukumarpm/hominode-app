const {sosStore} = require('./sos_store');
// Query-capable unit double; emulator tests independently verify Firestore behavior.
function moderationStore() {
  const db = sosStore();
  const collection = db.collection.bind(db);
  db.reads = [];
  const scalar = value => value?.valueOf?.() ?? value;
  const compare = (a,b) => scalar(a) < scalar(b) ? -1 : scalar(a) > scalar(b) ? 1 : 0;
  const query = (name, filters=[], orders=[], cap=Infinity, after) => {
    const read = () => {
      let rows = [...db.values.entries()].filter(([path]) => path.split('/').length === 2 && path.startsWith(name+'/'))
        .map(([path,data]) => ({id:path.split('/')[1], data:()=>data}));
      const field = (row,key) => typeof key === 'string' ? row.data()[key] : row.id;
      rows = rows.filter(row => filters.every(([key,op,value]) => op === '==' ? field(row,key) === value : field(row,key) !== undefined && compare(field(row,key),value) <= 0));
      rows = rows.filter(row => orders.every(([key]) => field(row,key) !== undefined));
      const cmp = (row,values) => {
        for (let i=0;i<orders.length;i++) {const result=compare(field(row,orders[i][0]),values[i])*(orders[i][1]==='desc'?-1:1); if(result) return result;}
        return 0;
      };
      rows.sort((a,b)=>cmp(a,orders.map(([key])=>field(b,key))));
      if (after) rows=rows.filter(row=>cmp(row,after)>0);
      return rows.slice(0,cap);
    };
    return {
      where:(...f)=>query(name,[...filters,f],orders,cap,after),
      orderBy:(...o)=>query(name,filters,[...orders,o],cap,after),
      limit:n=>query(name,filters,orders,n,after),
      startAfter:(...values)=>query(name,filters,orders,cap,values),
      count:()=>({get:async()=>({data:()=>({count:read().length})})}),
      get:async()=>{const docs=read();db.reads.push({name,cap,size:docs.length});return {docs,size:docs.length};},
    };
  };
  db.collection = name => ({...query(name), doc:id=>collection(name).doc(id)});
  db.runTransaction = async work => work({get:target=>target.get()});
  return db;
}
module.exports = {moderationStore};
