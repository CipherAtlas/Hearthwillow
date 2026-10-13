// Extract only the original note/quill/page; existing world authoring is untouched.
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const source = '/Users/sabar/Documents/cosy-v1';
const ts = require(path.join(source, 'node_modules/typescript'));
const T = require(path.join(source, 'node_modules/three/build/three.cjs'));
const input = fs.readFileSync(path.join(source, 'features/village/activityScene.ts'), 'utf8').replace(/^import .*;\n/gm, '').replace(/^export .* from .*;\n/gm, '');
const js = ts.transpileModule(input, {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022}}).outputText;
const moduleBox = {exports: {}};
vm.runInThisContext('(function(module,exports,T,ACTIVITY_STAGES,makeFocusHourglass,makeDeskQuill,mergeGeometries){' + js + '})')(
  moduleBox, moduleBox.exports, T, {}, () => ({hourglass: new T.Group(), topSand: new T.Mesh(), bottomSand: new T.Mesh(), stream: new T.Mesh()}), () => new T.Group(), () => new T.BufferGeometry());
global.FileReader = class {
  readAsArrayBuffer(blob) {blob.arrayBuffer().then(v => {this.result = v; this.onloadend?.();});}
  readAsDataURL(blob) {blob.arrayBuffer().then(v => {this.result = 'data:'+blob.type+';base64,'+Buffer.from(v).toString('base64'); this.onloadend?.();});}
};
(async () => {
  const {GLTFExporter} = await import(pathToFileURL(path.join(source, 'node_modules/three/examples/jsm/exporters/GLTFExporter.js')).href);
  const exporter = new GLTFExporter();
  const note = moduleBox.exports.makeKindNote(); note.flap.name = 'Flap'; note.sheet.name = 'Sheet';
  const activity = new moduleBox.exports.VillageActivities([]);
  const placesOnly = process.argv.includes('--places');
  activity.mintLeaves.name = 'MintLeaves';
  activity.cup.children.find(mesh => mesh.material === activity.teaLiquid).name = 'Liquid';
  activity.steam.forEach((mesh, index) => mesh.name = 'Steam'+index);
  const exports = placesOnly ? [['tea-cup', activity.cup]] : [['kind-note', note.root], ['writing-quill', activity.quill], ['saved-page', activity.page]];
  for (const [name, object] of exports) {
    object.removeFromParent(); object.position.set(0,0,0); object.visible = true;
    fs.writeFileSync('assets/quiet/'+name+'.glb', Buffer.from(await exporter.parseAsync(object, {binary:true, onlyVisible:false})));
  }
  if (placesOnly) { console.log('Saved original tea cup only.'); return; }
  const activities = fs.readFileSync(path.join(source,'features/village/Activities.tsx'),'utf8');
  const phrases = activities.match(/const phrases = (\[[\s\S]*?\]);/)[1];
  const phrasesJa = activities.match(/const phrasesJa = (\[[\s\S]*?\]);/)[1];
  fs.writeFileSync('assets/quiet/kind-notes.json', JSON.stringify({en:vm.runInNewContext(phrases), ja:vm.runInNewContext(phrasesJa)}, null, 2));
  console.log('Saved original note, quill, page and bilingual note content.');
})();
