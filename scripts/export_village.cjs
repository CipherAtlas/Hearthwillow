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
const destination = path.join(root, 'assets/village');
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
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname === '/') { response.setHeader('Content-Type', 'text/html'); response.end('<style>body{margin:0}#scene{position:fixed;inset:0}</style><div id="scene"></div><script type="importmap">{"imports":{"three":"/three/build/three.module.js","three/addons/":"/three/examples/jsm/"}}</script>'); return; }
    const base = url.pathname.startsWith('/three/') ? path.join(source, 'node_modules') : url.pathname.startsWith('/village/') ? path.join(source, 'public') : temporary;
    const file = path.resolve(base, '.' + url.pathname);
    if (!file.startsWith(base + path.sep)) { response.writeHead(403); response.end(); return; }
    response.setHeader('Content-Type', file.endsWith('.js') ? 'text/javascript' : file.endsWith('.json') ? 'application/json' : 'application/octet-stream');
    const stream = fs.createReadStream(file); stream.on('error', () => { response.writeHead(404); response.end(); }); stream.pipe(response);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ headless: true, channel: 'chrome' });
    const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });
    page.on('pageerror', error => console.error(error.message));
    await page.exposeFunction('writeAsset', (name, data) => {
      if (!/^[a-zA-Z0-9_.-]+$/.test(name)) throw Error('Invalid output name');
      fs.writeFileSync(path.join(destination, name), Buffer.from(data, 'base64'));
    });
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    console.log('Loading the unchanged production village…');
    const birdsOnly = process.argv.includes("--birds-only");
    const manifest = await page.evaluate(async birdsOnly => {
      const T = await import('three');
      const { VillageEngine } = await import('/modules/features/village/VillageEngine.js');
      const env = await import('/modules/features/village/environment.js');
      const { VILLAGERS } = await import('/modules/features/village/villagers.js');
      const noop = () => {};
      const e = new VillageEngine(document.querySelector('#scene'), { progress: noop, ready: noop, near: noop, interact: noop, error: message => { throw Error(message); }, stats: noop, movement: noop, contact: noop, environment: noop });
      await e.load(); e.setQuality('high'); e.setWeather('golden'); e.setBlocked(false); e.renderer.setAnimationLoop(null);
      e.frame(performance.now() + 16); e.scene.updateMatrixWorld(true);
      window.sourceEngine = e;
      const output = { version: 1, geometries: [], materials: [], meshes: [], points: [], buildings: e.world.mapScenery.buildings, textures: [], colliders: e.world.colliders.filter(c => !c.bridgeRail).concat(env.bridgeBarriers()), layout: e.world.authored, spawn: [0.3, env.floorHeight(0.3, 20), 20], spiritScale: e.spiritScale, lights: [], skipped: [] };
      const route = (id, spine, width) => ({ id, spine, width, bounds: [Math.min(...spine.map(p => p[0])), Math.min(...spine.map(p => p[1])), Math.max(...spine.map(p => p[0])), Math.max(...spine.map(p => p[1]))] });
      const placedPoint = (item, x, z) => {
        const yaw = item.rotation[1] * Math.PI / 180;
        return [item.position[0] + x * item.scale[0] * Math.cos(yaw) + z * item.scale[2] * Math.sin(yaw), item.position[2] - x * item.scale[0] * Math.sin(yaw) + z * item.scale[2] * Math.cos(yaw)];
      };
      const sourcePaths = e.world.mapScenery.paths;
      const inheritedCount = sourcePaths.length - output.layout.paths.length;
      output.paths = [];
      for (let i = 0; i < inheritedCount; i++) {
        const template = sourcePaths[i], pivot = template.spine[50];
        for (const item of output.layout.items.filter(item => item.visible && item.asset === `path-${i + 1}`)) {
          output.paths.push(route(item.id, template.spine.map(p => placedPoint(item, p[0] - pivot[0], p[1] - pivot[1])), template.width * Math.sqrt(Math.abs(item.scale[0] * item.scale[2]))));
        }
      }
      output.layout.paths.forEach((path, i) => output.paths.push(route(path.id, sourcePaths[inheritedCount + i].spine, path.width)));
      output.rivers = [...output.layout.rivers];
      output.actors = e.life.residents.map((resident, index) => ({ ...VILLAGERS[index], kind: 'resident', transform: resident.root.matrixWorld.toArray(), route: resident.route, pauses: resident.routePauses, pace: resident.pace, phase: resident.phase, visible: resident.root.visible }));
      output.birds = {
        landings: e.birds.birds.map(b => b.landing.toArray()),
        scales: e.birds.birds.map(b => b.root.scale.toArray()),
        curves: e.birds.flightRoutes.map(curve => Array.from({length: 301}, (_, i) => curve.getPointAt(i / 300).toArray())),
        parts: e.birds.parts.map(part => {
          const bird = e.birds.birds[0];
          bird.head.rotation.set(0,0,0); bird.wings.forEach(wing => wing.rotation.set(0,0,0)); bird.root.updateMatrixWorld(true);
          const relative = bird.root.matrixWorld.clone().invert().multiply(part.nodes[0].matrixWorld);
          const pivot = part.nodes[0].parent;
          const parentTransform = bird.root.matrixWorld.clone().invert().multiply(pivot.matrixWorld);
          return {name: part.mesh.name, transform: relative.toArray(), pivot: parentTransform.toArray()};
        })
      };
      if (birdsOnly) return {birds: output.birds};
      const actorRoots = new Map(e.life.residents.map((resident, index) => [resident.root, VILLAGERS[index].id]));
      e.puppies.puppies.forEach(puppy => actorRoots.set(puppy.actor, puppy.info.id));
      for (const item of output.layout.items.filter(item => item.visible && item.asset === 'river')) {
        const spine = Array.from({ length: 221 }, (_, i) => { const z = i - 110; return placedPoint(item, -11 + Math.sin(z * .052) * 3, z); });
        output.rivers.push(route(item.id, spine, 6.4 * Math.sqrt(Math.abs(item.scale[0] * item.scale[2]))));
      }
      const chunks = []; let offset = 0;
      const store = values => {
        const bytes = new Uint8Array(values.buffer, values.byteOffset, values.byteLength);
        const record = { offset, bytes: bytes.length }; chunks.push(bytes); offset += bytes.length; return record;
      };
      const geometries = new Map(), materials = new Map(), textures = new Map();
      const texture = async value => {
        if (!value?.image) return null;
        if (textures.has(value.uuid)) return textures.get(value.uuid);
        const image = value.image;
        const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
        const context = canvas.getContext('2d');
        if (image.data) context.putImageData(new ImageData(new Uint8ClampedArray(image.data.buffer), image.width, image.height), 0, 0);
        else context.drawImage(image, 0, 0);
        const id = output.textures.length, name = `texture_${id}.png`;
        await window.writeAsset(name, canvas.toDataURL('image/png').split(',')[1]);
        textures.set(value.uuid, id);
        output.textures.push({ name, repeat: value.repeat.toArray(), offset: value.offset.toArray(), flipY: value.flipY, clamp: value.wrapS === T.ClampToEdgeWrapping, srgb: value.colorSpace === T.SRGBColorSpace }); return id;
      };
      const material = async m => {
        if (materials.has(m.uuid)) return materials.get(m.uuid);
        const id = output.materials.length; materials.set(m.uuid, id); output.materials.push(null);
        const shaderKey = m.customProgramCacheKey?.() || '';
        const uniforms = Object.fromEntries(Object.entries(m.uniforms || {}).map(([key, { value }]) => [key, value?.toArray ? value.toArray() : value]));
        output.materials[id] = { name: m.name, color: (m.color || new T.Color('white')).toArray(), opacity: m.opacity, roughness: m.roughness ?? 1, metalness: m.metalness || 0, emissive: (m.emissive || new T.Color('black')).toArray(), emissionEnergy: m.emissiveIntensity ?? 1, vertexColors: !!m.vertexColors, doubleSided: m.side === T.DoubleSide, transparent: !!m.transparent, alphaTest: m.alphaTest || 0, unshaded: !!(m.isMeshBasicMaterial || m.isShaderMaterial), map: await texture(m.map), shaderKey, vertexShader: m.vertexShader, fragmentShader: m.fragmentShader, uniforms };
        return id;
      };
      const geometry = (g, range, skinned) => {
        const key = g.uuid + (range ? `:${range.vertexStart}:${range.indexStart}` : '') + (skinned ? ':skin' : '');
        if (geometries.has(key)) return geometries.get(key);
        const id = output.geometries.length; geometries.set(key, id);
        const start = range?.vertexStart || 0, count = range?.vertexCount || g.attributes.position.count;
        const record = { count, attributes: {} };
        const attributes = { position: g.attributes.position, normal: g.attributes.normal, uv: g.attributes.uv, color: g.attributes.color, uv2: g.attributes.flameSeed || g.attributes.uv2 };
        const p = new T.Vector3();
        for (const [name, a] of Object.entries(attributes)) {
          if (!a) continue;
          const size = name === 'uv2' ? 2 : name === 'color' ? 4 : a.itemSize;
          const data = new Float32Array(count * size);
          for (let i = 0; i < count; i++) {
            for (let c = 0; c < size; c++) data[i * size + c] = c < a.itemSize ? a.getComponent(start + i, c) : name === 'color' ? 1 : 0;
            if (skinned && name === 'position') { p.fromArray(data, i * size); skinned.applyBoneTransform(start + i, p); p.toArray(data, i * size); }
          }
          record.attributes[name] = store(data);
        }
        const indexStart = range?.indexStart || g.drawRange.start || 0;
        const indexCount = range?.indexCount || Math.min(g.index?.count || count, Number.isFinite(g.drawRange.count) ? g.drawRange.count : Infinity);
        const indices = new Int32Array(indexCount);
        // Godot's front-face winding is clockwise; Three.js uses counterclockwise.
        for (let i = 0; i < indexCount; i += 3) { const tri = [0, 2, 1]; for (let c = 0; c < 3; c++) indices[i + c] = (g.index ? g.index.getX(indexStart + i + tri[c]) : indexStart + i + tri[c]) - start; }
        record.indices = store(indices); output.geometries.push(record); return id;
      };
      const excluded = new Set([e.player, e.atmosphere.sky, e.activities?.indoor, e.indoorLight]);
      const visible = object => { for (let p = object; p; p = p.parent) if (!p.visible || excluded.has(p)) return false; return true; };
      const matrix = new T.Matrix4(), color = new T.Color();
      const add = async (object, g, transforms, colors, range) => {
        const mats = Array.isArray(object.material) ? object.material : [object.material];
        if (mats.length !== 1) throw Error(`Unhandled multimaterial mesh: ${object.name}`);
        const ancestors = []; for (let p = object; p && p !== e.scene; p = p.parent) if (p.name) ancestors.unshift(p.name);
        let actor = null; for (let p = object; p && p !== e.scene; p = p.parent) if (actorRoots.has(p)) { actor = actorRoots.get(p); break; }
        output.meshes.push({ name: ancestors.join('/') || `Scenery ${output.meshes.length}`, actor, part: object.name, geometry: geometry(g, range, object.isSkinnedMesh ? object : null), material: await material(mats[0]), transforms: store(new Float32Array(transforms)), colors: colors ? store(new Float32Array(colors)) : null, count: transforms.length / 16, castShadow: object.castShadow });
      };
      const objects = []; e.scene.traverse(o => { if (visible(o)) objects.push(o); });
      for (const object of objects) {
        if (object.isLight) { if (object.isPointLight && object.intensity > 0) output.lights.push({ name: object.name, position: object.getWorldPosition(new T.Vector3()).toArray(), color: object.color.toArray(), energy: object.intensity, range: object.distance }); continue; }
        if (object.isPoints) {
          const id = await material(object.material);
          output.materials[id].points = true;
          output.materials[id].additive = object.material.blending === T.AdditiveBlending;
          output.points.push({ name: object.name, material: id, seeds: store(new Float32Array(object.geometry.attributes.position.array)), transform: object.matrixWorld.toArray() });
          continue;
        }
        if (!object.isMesh) { if (object.isSprite) output.skipped.push({ name: object.name, type: object.type }); continue; }
        if (object.isBatchedMesh) {
          const batches = new Map();
          for (let i = 0; i < object.instanceCount; i++) {
            try {
              if (!object.getVisibleAt(i)) continue;
              const gid = object.getGeometryIdAt(i); if (gid < 0) continue;
              if (!batches.has(gid)) batches.set(gid, { transforms: [], colors: [] });
              object.getMatrixAt(i, matrix); matrix.premultiply(object.matrixWorld); batches.get(gid).transforms.push(...matrix.elements);
              color.set('white'); object.getColorAt(i, color); batches.get(gid).colors.push(...color.toArray(), 1);
            } catch (error) { throw Error(`Batch ${object.name}/${i}: ${error.message}`); }
          }
          for (const [gid, batch] of batches) await add(object, object.geometry, batch.transforms, batch.colors, object.getGeometryRangeAt(gid));
        } else if (object.isInstancedMesh) {
          if (!object.count) continue;
          const transforms = [], colors = [];
          for (let i = 0; i < object.count; i++) { object.getMatrixAt(i, matrix); matrix.premultiply(object.matrixWorld); transforms.push(...matrix.elements); color.set('white'); if (object.instanceColor) object.getColorAt(i, color); colors.push(...color.toArray(), 1); }
          await add(object, object.geometry, transforms, colors);
        } else await add(object, object.geometry, object.matrixWorld.toArray(), null);
      }
      output.sky = { fragmentShader: e.atmosphere.sky.material.fragmentShader, uniforms: Object.fromEntries(Object.entries(e.atmosphere.sky.material.uniforms).map(([key, { value }]) => [key, value?.toArray ? value.toArray() : value])) };
      output.bounds = { min: -320, max: 320, step: 1, width: 641 };
      const floors = new Float32Array(641 * 641), allowed = new Int32Array(floors.length);
      for (let z = 0; z < 641; z++) for (let x = 0; x < 641; x++) {
        const wx = x - 320, wz = z - 320, i = z * 641 + x;
        floors[i] = env.floorHeight(wx, wz);
        allowed[i] = env.inWalkableWorld(wx, wz) && (!env.inRiver(wx, wz) || env.onBridge(wx, wz)) && (env.pondDistance(wx, wz) >= 1.035 || env.onPondDock(wx, wz)) ? 1 : 0;
      }
      output.floorHeights = store(floors); output.allowedGround = store(allowed);
      // Fine floor patches keep the original four bridge openings and sloped decks traversable.
      output.bridgeFloors = [];
      for (const item of output.layout.items.filter(i => i.visible && i.asset === 'bridge')) {
        const [cx, cy, cz] = item.position; const step = .2;
        const extent = Math.ceil(Math.max(8 * item.scale[0], 4 * item.scale[2]));
        const width = Math.ceil(extent * 2 / step) + 1, heights = new Float32Array(width * width);
        for (let z = 0; z < width; z++) for (let x = 0; x < width; x++) heights[z * width + x] = env.floorHeight(cx - extent + x * step, cz - extent + z * step);
        output.bridgeFloors.push({ x: cx - extent, z: cz - extent, width, step, heights: store(heights) });
      }
      const bytes = new Uint8Array(offset); let at = 0; for (const chunk of chunks) { bytes.set(chunk, at); at += chunk.length; }
      // Transfer bounded blocks so large villages do not exceed the browser protocol message limit.
      for (let start = 0, part = 0; start < bytes.length; start += 512 * 1024, part++) {
        const data = bytes.subarray(start, start + 512 * 1024); let binary = ''; for (let i = 0; i < data.length; i += 8192) binary += String.fromCharCode(...data.subarray(i, i + 8192));
        await window.writeAsset(`geometry.part${part}`, btoa(binary));
      }
      output.binaryBytes = bytes.length; output.parts = Math.ceil(bytes.length / (512 * 1024));
      return output;
    }, birdsOnly);
    if (birdsOnly) {
      for (const name of ['manifest.json','world-data.json']) {
        const file = path.join(destination,name), saved = JSON.parse(fs.readFileSync(file,'utf8'));
        saved.birds = manifest.birds; fs.writeFileSync(file,JSON.stringify(saved));
      }
      console.log('Captured native flock metadata.'); return;
    }
    const descriptor = fs.openSync(path.join(destination, 'geometry.bin'), 'w');
    for (let i = 0; i < manifest.parts; i++) { const file = path.join(destination, `geometry.part${i}`); fs.writeSync(descriptor, fs.readFileSync(file)); fs.unlinkSync(file); } fs.closeSync(descriptor);
    manifest.source = { path: source, commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: source, encoding: 'utf8' }).trim(), layoutSha256: createHash('sha256').update(fs.readFileSync(path.join(source, 'public/village/world-layout.json'))).digest('hex') };
    fs.writeFileSync(path.join(destination, 'manifest.json'), JSON.stringify(manifest));
    fs.copyFileSync(path.join(source, 'public/village/world-layout.json'), path.join(destination, 'world-layout.json'));
    fs.copyFileSync(path.join(source, 'public/village/CREDITS.txt'), path.join(destination, 'CREDITS.txt'));
    fs.copyFileSync(path.join(source, 'node_modules/three/LICENSE'), path.join(root, 'THREE-LICENSE.txt'));
    fs.mkdirSync(path.join(root, 'assets/spirit'), { recursive: true });
    fs.mkdirSync(path.join(root, 'assets/animals'), { recursive: true });
    fs.copyFileSync(path.join(source, 'public/village/models/farm-props.glb'), path.join(root, 'assets/animals/farm-props.glb'));
    fs.copyFileSync(path.join(source, 'public/village/models/spirit.glb'), path.join(root, 'assets/spirit/spirit.glb'));
    fs.mkdirSync(path.join(root, 'assets/audio'), { recursive: true });
    fs.mkdirSync(path.join(root, 'assets/animals'), { recursive: true });
    for (const slug of ['dog-corgi','dog-shiba','dog-beagle','dog-samoyed','highland-copper','highland-flower','sheep','lamb','owl','horse-bay','horse-grey']) fs.copyFileSync(path.join(source,'public/village/models/animals-v2',slug+'.glb'),path.join(root,'assets/animals',slug+'.glb'));
    for (const name of ['cow','sheep','lamb','hedgehog','owl','horse','dove']) fs.copyFileSync(path.join(source,'public/village/audio/animals',name+'.mp3'),path.join(root,'assets/audio',name+'.mp3'));
    for (const name of ['mochi','kiko','biscuit','cloud']) fs.copyFileSync(path.join(source,'public/village/audio/puppies',name+'-yip.mp3'),path.join(root,'assets/audio',name+'-yip.mp3'));
    for (const name of ['world/stream.mp3', 'world/fire.mp3', 'world/rain.mp3', 'music/quiet-village-1.mp3']) fs.copyFileSync(path.join(source, 'public/village/audio', name), path.join(root, 'assets/audio', path.basename(name)));
    fs.mkdirSync(path.join(root, 'evidence'), { recursive: true });
    await page.evaluate(() => { const e = window.sourceEngine; e.view.walking({ player: e.player, yaw: 0, pitch: .15, distance: 3.8, seated: false, colliders: e.world.colliders, items: e.world.authored.items }); e.camera.position.copy(e.view.goal); e.camera.lookAt(e.view.look); e.renderer.render(e.scene, e.camera); });
    await page.locator('canvas').first().screenshot({ path: path.join(root, 'evidence/source-entrance.png') });
    console.log(JSON.stringify({ meshes: manifest.meshes.length, geometries: manifest.geometries.length, instances: manifest.meshes.reduce((n, m) => n + m.count, 0), materials: manifest.materials.length, textures: manifest.textures.length, colliders: manifest.colliders.length, bytes: manifest.binaryBytes, skipped: manifest.skipped.length }, null, 2));
  } finally { if (browser) await browser.close(); await new Promise(resolve => server.close(resolve)); fs.rmSync(temporary, { recursive: true, force: true }); }
})().catch(error => { console.error(error); process.exitCode = 1; });
