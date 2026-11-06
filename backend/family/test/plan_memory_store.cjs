'use strict';
const {MemoryStore}=require('./memory_store.cjs');
class PlanMemoryStore extends MemoryStore {
  collection(path) {
    const build=(filters=[],order=null,max=null)=>({path,query:true,
      doc:id=>this.doc(path+'/'+id),
      where:(field,operator,value)=>build([...filters,{field,operator,value}],order,max),
      orderBy:(field,direction='asc')=>build(filters,{field,direction},max),
      limit:count=>build(filters,order,count),filters,order,max,
    });
    return build();
  }
  runTransaction(action) {
    return super.runTransaction(tx=>action({...tx,get:async ref=>{
      const result=await tx.get(ref);if(!ref.query)return result;
      const field=(row,key)=>key.split('.').reduce((value,k)=>value?.[k],row);
      let docs=result.docs.filter(doc=>(ref.filters??[]).every(f=>f.operator==='=='&&field(doc.data(),f.field)===f.value));
      if(ref.order)docs.sort((a,b)=>{const av=field(a.data(),ref.order.field),bv=field(b.data(),ref.order.field);return (av<bv?-1:av>bv?1:0)*(ref.order.direction==='desc'?-1:1);});
      if(ref.max!==null&&ref.max!==undefined)docs=docs.slice(0,ref.max);
      return {docs};
    }}));
  }
}
module.exports={PlanMemoryStore};
