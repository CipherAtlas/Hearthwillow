// Convert the unchanged source dish/cooking builders into native saved assets.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {pathToFileURL} = require('node:url');
const source = '/Users/sabar/Documents/cosy-v1';
const ts = require(path.join(source,'node_modules/typescript'));
const T = require(path.join(source,'node_modules/three/build/three.cjs'));
function compile(file, injected) {
  const input = fs.readFileSync(path.join(source,'features/village',file),'utf8').replace(/^import .*;\n/gm,'');
  const js = ts.transpileModule(input,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  const module = {exports:{}};
  const keys=Object.keys(injected);
  vm.runInThisContext('(function(module,exports,'+keys.join(',')+'){'+js+'})')(module,module.exports,...Object.values(injected));
  return module.exports;
}
class ExportFileReader {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(value=>{this.result=value;this.onloadend?.();}); }
  readAsDataURL(blob) { blob.arrayBuffer().then(value=>{this.result='data:'+blob.type+';base64,'+Buffer.from(value).toString('base64');this.onloadend?.();}); }
}
global.FileReader = ExportFileReader;
(async()=>{
  const {GLTFExporter} = await import(pathToFileURL(path.join(source,'node_modules/three/examples/jsm/exporters/GLTFExporter.js')).href);
  const kitchen = compile('gardenKitchenScene.ts',{T});
  const {makePicnicDish} = compile('picnicScene.ts',{T,...kitchen});
  const exporter = new GLTFExporter();
  fs.mkdirSync('assets/gameplay',{recursive:true});
  for(const recipe of ['gardenSoup','crispSalad','bakedApples','roastRoots']) {
    const dish = makePicnicDish(recipe);
    fs.writeFileSync('assets/gameplay/'+recipe+'.glb',Buffer.from(await exporter.parseAsync(dish,{binary:true})));
    const cooking = new kitchen.KitchenCookingVisual(makePicnicDish);
    cooking.update({recipe,startedAt:0,readyAt:4500},2000,false);
    cooking.spoon.name='Spoon'; cooking.knife.name='Knife'; cooking.puffs.name='Steam'; cooking.ingredients.name='Ingredients'; cooking.glow.name='Heat'; cooking.liquid.name='Liquid';
    fs.writeFileSync('assets/gameplay/'+recipe+'-cooking.glb',Buffer.from(await exporter.parseAsync(cooking.root,{binary:true,onlyVisible:false})));
  }
  console.log('Saved 4 original dishes and 4 original cooking visual templates.');
})();
