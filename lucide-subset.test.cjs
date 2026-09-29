const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {usedIcons}=require('./vendor/build-lucide-subset.cjs');

// A tiny DOM: enough for lucide's createIcons (attributes, querySelectorAll,
// createElementNS, replaceChild) and a stable serialisation to compare output.
function makeDocument(){
  const make=(tag,ns)=>{
    const node={tagName:tag,ns,attrs:new Map(),children:[],parentNode:null,
      get attributes(){return [...node.attrs].map(([name,value])=>({name,value}));},
      getAttribute:k=>node.attrs.has(k)?node.attrs.get(k):null,
      setAttribute:(k,v)=>node.attrs.set(k,String(v)),
      appendChild:c=>{c.parentNode=node;node.children.push(c);return c;},
      replaceChild:(next,old)=>{node.children[node.children.indexOf(old)]=next;next.parentNode=node;old.parentNode=null;return old;},
      get outerHTML(){return `<${tag}>`;}};
    return node;
  };
  const body=make('body');
  const all=node=>node.children.flatMap(c=>[c,...all(c)]);
  const document={body,createElementNS:(ns,tag)=>make(tag,ns),
    querySelectorAll:sel=>{const attr=sel.slice(1,-1);return all(body).filter(n=>n.attrs.has(attr));}};
  const serialise=node=>`<${node.tagName}${[...node.attrs].sort().map(([k,v])=>` ${k}="${v}"`).join('')}>${node.children.map(serialise).join('')}</${node.tagName}>`;
  return {document,body,make,serialise};
}
function render(libPath,build){
  const dom=makeDocument();
  const context={document:dom.document,console,window:{}};
  context.self=context.window;
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(libPath,'utf8'),context);
  const lucide=context.window.lucide||context.lucide;
  build(dom);lucide.createIcons();
  // A second pass re-replaces existing svgs, as repeated createIcons() calls do in the game.
  lucide.createIcons({root:dom.body});
  return dom.serialise(dom.body);
}
const scene=names=>({body,make})=>{
  for(const name of names){
    const plain=make('i');plain.setAttribute('data-lucide',name);body.appendChild(plain);
    const wrap=make('span');body.appendChild(wrap);
    const decorated=make('i');decorated.setAttribute('data-lucide',name);decorated.setAttribute('aria-hidden','true');decorated.setAttribute('class','extra lucide');wrap.appendChild(decorated);
  }
};

test('the subset renders every used icon exactly like full lucide',()=>{
  const names=usedIcons();
  assert.ok(names.length>50,'icon scan should find the skill catalog icons');
  assert.equal(render(__dirname+'/vendor/lucide-subset.js',scene(names)),render(__dirname+'/vendor/lucide.min.js',scene(names)));
});

test('the subset is up to date with the icons referenced in source',()=>{
  const header=fs.readFileSync(__dirname+'/vendor/lucide-subset.js','utf8').match(/\d+ icons: ([^\n]*)/)[1].split(' ');
  assert.deepEqual(header,usedIcons(),'run: node vendor/build-lucide-subset.cjs');
});
