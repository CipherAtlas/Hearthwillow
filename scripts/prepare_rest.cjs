// Development-only conversion. The shipped game has no browser or Three.js dependency.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const { execFileSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
const root = path.resolve(__dirname, '..');
const source = path.resolve(process.argv[2] || '/Users/sabar/Documents/cosy-v1');
const destination = path.join(root, 'assets/rest');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'hearthwillow-convert-'));
fs.mkdirSync(destination, { recursive: true });

function compileSource() {
  const config = { compilerOptions: { target: 'ES2022', module: 'ES2022', moduleResolution: 'bundler', outDir: path.join(temporary, 'modules'), rootDir: source, baseUrl: source, paths: { '@/*': ['./*'] }, skipLibCheck: true, typeRoots: [path.join(source, 'node_modules/@types')], types: ['node'] }, files: [path.join(source, 'features/village/VillageEngine.ts')] };
  const configPath = path.join(temporary, 'tsconfig.json');
  fs.writeFileSync(configPath, JSON.stringify(config));
  execFileSync(path.join(source, 'node_modules/.bin/tsc'), ['-p', configPath], { stdio: 'inherit' });
  function rewrite(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) rewrite(file);
      else if (file.endsWith('.js')) fs.writeFileSync(file, fs.readFileSync(file, 'utf8')
        .replaceAll('"@/lib/basePath"', '"../../lib/basePath.js"')
        .replace(/(from\s+["'])(\.[^"']+)(["'])/g, (_, a, b, c) => a + b + (b.endsWith('.js') ? '' : '.js') + c)
        .replaceAll('process.env.NEXT_PUBLIC_BASE_PATH', '""'));
    }
  }
  rewrite(path.join(temporary, 'modules'));
}

(async () => {
  compileSource();
  const server = http.createServer((request,response)=>{
    const url = new URL(request.url,'http://localhost');
    if(url.pathname==='/'){response.setHeader('Content-Type','text/html');response.end('<div id="scene"></div><script type="importmap">{"imports":{"three":"/three/build/three.module.js","three/addons/":"/three/examples/jsm/"}}</script>');return;}
    const base=url.pathname.startsWith('/three/')?path.join(source,'node_modules'):url.pathname.startsWith('/village/')?path.join(source,'public'):temporary;
    const file=path.resolve(base,'.'+url.pathname);
    if(!file.startsWith(base+path.sep)){response.writeHead(403);response.end();return;}
    response.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'application/octet-stream');
    fs.createReadStream(file).on('error',()=>{response.writeHead(404);response.end();}).pipe(response);
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  let browser;
  try {
    browser=await chromium.launch({headless:true,channel:'chrome'});
    const page=await browser.newPage({viewport:{width:1920,height:1080}});
    await page.exposeFunction('writeRest',(name,data)=>fs.writeFileSync(path.join(destination,name),Buffer.from(data,'base64')));
    await page.goto('http://127.0.0.1:'+server.address().port);
    const metadata=await page.evaluate(async()=>{
      const T=await import('three'); const {GLTFExporter}=await import('three/addons/exporters/GLTFExporter.js');
      const {VillageEngine}=await import('/modules/features/village/VillageEngine.js');
      const noop=()=>{}; const e=new VillageEngine(document.querySelector('#scene'),{progress:noop,ready:noop,near:noop,interact:noop,error:m=>{throw Error(m)},stats:noop,movement:noop,contact:noop,environment:noop});
      await e.load(); e.renderer.setAnimationLoop(null);
      const exporter=new GLTFExporter();
      const save=async(name,obj)=>{const buffer=await exporter.parseAsync(obj,{binary:true,onlyVisible:false}); let b='';for(const byte of new Uint8Array(buffer))b+=String.fromCharCode(byte);await window.writeRest(name,btoa(b));};
      const interior=e.indoor.clone(true); interior.position.set(0,0,0); interior.visible=true;
      interior.traverse(o=>{if(o.isMesh&&o.material.map===e.bridgeWindow.texture){o.name='BridgeView';o.material=new T.MeshBasicMaterial({color:'#91aeb4'});}});
      await save('focus-room.glb',interior);
      e.activities.sandTop.name='Top';e.activities.sandBottom.name='Bottom';e.activities.sandStream.name='Stream';e.activities.sandTop.parent.name='Hourglass';e.activities.deskQuill.name='Quill'; const dynamic=e.activities.indoor.clone(true);dynamic.visible=true;dynamic.position.x=-110;dynamic.traverse(o=>{o.visible=true;});
      await save('focus-desk.glb',dynamic);
      for(const swing of e.world.swings){swing.pivots.forEach((p,i)=>{p.name='Pivot'+i;p.children.find(c=>c.isGroup).name='Carrier';}); await save(swing.placement.id+'.glb',swing.root);}
      const benches=e.world.benches.map(b=>({id:b.id,x:b.x,z:b.z,facing:b.facing,seatHeight:b.seatHeight,seatSpacing:b.seatSpacing,seatCount:b.seatCount,birdClearing:b.birdClearing,hitBox:{min:b.hitBox.min.toArray(),max:b.hitBox.max.toArray()}}));
      const result={benches,swings:e.world.swings.map(s=>s.placement)};e.dispose();return result;
    });
    fs.writeFileSync(path.join(destination,'rest-data.json'),JSON.stringify(metadata,null,2));
    const cat=path.join(source,'public/village/models/animals-v2/cat.glb');
    if(fs.existsSync(cat))fs.copyFileSync(cat,path.join(destination,'cat.glb'));
    console.log('Exported original cottage, desk, swing hierarchies and '+metadata.benches.length+' bench records.');
  } finally {await browser?.close();server.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1});
