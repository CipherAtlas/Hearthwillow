// Read-only reuse of the original React map artwork; Godot ships the saved SVG.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = '/Users/sabar/Documents/cosy-v1';
const ts = require(path.join(source, 'node_modules/typescript'));
const React = require(path.join(source, 'node_modules/react'));
const {renderToStaticMarkup} = require(path.join(source, 'node_modules/react-dom/server'));
const cache = new Map();
function load(file) {
  if (cache.has(file)) return cache.get(file).exports;
  let input = fs.readFileSync(file, 'utf8');
  if (file.endsWith('VillageMap.tsx')) input += '\nexport { MapLandscape, mapBounds };';
  const content = ts.transpileModule(input, {compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
  const module = {exports:{}}; cache.set(file,module);
  function dependency(name) {
    if (name === '@phosphor-icons/react') return load(path.join(source,'node_modules/@phosphor-icons/react/dist/index.cjs.js'));
    if (!name.startsWith('.') && !name.startsWith('@/')) return require(path.join(source,'node_modules',name));
    const base = name.startsWith('@/') ? path.join(source,name.slice(2)) : path.resolve(path.dirname(file),name);
    const target = ['.ts','.tsx','.js'].map(ext=>base+ext).find(f=>fs.existsSync(f));
    if (!target) throw new Error('Missing source module '+base);
    return load(target);
  }
  vm.runInThisContext('(function(require,module,exports){'+content+'\n})',{filename:file})(dependency,module,module.exports);
  return module.exports;
}
const manifest = JSON.parse(fs.readFileSync('assets/village/manifest.json'));
const {MapLandscape,mapBounds} = load(path.join(source,'features/village/VillageMap.tsx'));
const scenery = {layout:manifest.layout,paths:manifest.paths,buildings:manifest.buildings,trees:manifest.layout.trees,benches:manifest.layout.benches};
const bounds = mapBounds(scenery);
const svg = renderToStaticMarkup(React.createElement('svg',{xmlns:'http://www.w3.org/2000/svg',width:bounds.width*10,height:bounds.height*10,viewBox:`0 0 ${bounds.width*10} ${bounds.height*10}`},React.createElement(MapLandscape,{scenery,bounds}))).replace(/(fill|stroke)="#([0-9a-f]{6})([0-9a-f]{2})"/gi,(_,attr,color,alpha)=>`${attr}="#${color}" ${attr}-opacity="${parseInt(alpha,16)/255}"`);
fs.writeFileSync('assets/village/map-art.svg',svg);
const {PLACES,JAPANESE_PLACE_NAMES} = load(path.join(source,'features/village/places.ts'));
const {outdoorMapDestinations} = load(path.join(source,'features/village/mapDestinations.ts'));
const icons = load(path.join(source,'node_modules/@phosphor-icons/react/dist/index.cjs.js'));
const mainIcons = ['Timer','Fire','Drop','Coffee','BookOpen','EnvelopeSimple','Leaf','Bird'];
const destinations = PLACES.map((p,i)=>({id:p.id,name:p.name,japanese:JAPANESE_PLACE_NAMES[i],point:[p.position[0],p.position[2]],icon:mainIcons[i]})).filter(p=>p.id!=='mood');
for(const p of outdoorMapDestinations(manifest.layout).filter((p,i,list)=>p.kind!=='swing'||i===list.findIndex(p=>p.kind==='swing'))) destinations.push({...p,name:p.kind==='swing'?'Meadow Swings':p.name,point:[p.x,p.z],icon:p.kind==='tower'?'CastleTurret':p.kind==='owls'?'Bird':p.kind==='circuit'?'Timer':'Leaf'});
// Original place constants predate the current authored layout. Derive markers
// from the same saved placement data used by physics, crops and world sound.
const world = JSON.parse(fs.readFileSync('assets/village/world-data.json'));
const anchors = {music:'hearth',breathe:'pond',compliment:'postbox',birds:'bird-clearing-bench'};
for (const destination of destinations) {
  const item = world.items.find(item=>item.id===anchors[destination.id]);
  if (!item) continue;
  destination.point = [item.position[0],item.position[2]];
  if (destination.id==='music') destination.arrival = [item.position[0],item.position[2]+4];
  if (destination.id==='breathe') {
    const dock = world.items.find(item=>item.id==='dock');
    destination.arrival = [dock.position[0],dock.position[2]];
  }
  if (destination.id==='birds') destination.arrival = [item.position[0],item.position[2]-2.5];
}
fs.mkdirSync('assets/ui',{recursive:true});
for(const name of new Set([...destinations.map(p=>p.icon),'GearSix','Basket','Leaf','ArrowUpRight','Keyboard','SpeakerHigh','PawPrint','CaretDown','X'])) fs.writeFileSync(`assets/ui/${name}.svg`,renderToStaticMarkup(React.createElement(icons[name],{size:24,color:'#fff5e4',weight:'regular'})));
fs.writeFileSync('assets/village/map-destinations.json',JSON.stringify({bounds,destinations},null,2)+'\n');
console.log(JSON.stringify({bounds,destinations:destinations.length,svgBytes:svg.length}));
