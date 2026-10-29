"use client";

import { useEffect, useRef, useState } from "react";
import { Minus, Plus, RotateCcw } from "lucide-react";
import * as THREE from "three";

type SceneKind = "safe" | "vehicles" | "crate" | "marks" | "cube" | "prism" | "capacity" | "generic";
type CargoPart = "cargo" | "safe" | "boxes" | "seal" | "support";
type Dimensions = [number, number, number]; // comprimento, altura, largura
type Controls = { rotate: (angle: number) => void; zoom: (delta: number) => void; reset: () => void };

const unit = 1 / 30;
const safe: Dimensions = [100, 70, 80];
const vehicles: Record<string, Dimensions> = {
  A: [95, 60, 75],
  B: [140, 100, 110],
  C: [120, 60, 90],
};
const parts: { id: CargoPart; label: string; measures: string }[] = [
  { id: "cargo", label: "Compartimento B", measures: "140 × 110 × 100 cm" },
  { id: "safe", label: "Cofre", measures: "100 × 80 × 70 cm" },
  { id: "boxes", label: "Duas caixas", measures: "60 × 40 × 30 cm cada" },
  { id: "seal", label: "Lacre", measures: "20 cm de aresta" },
  { id: "support", label: "Suporte", measures: "Base: 30 × 40 cm · comprimento: 60 cm" },
];

function normalize(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function identify(title: string, description: string, order: number): SceneKind {
  const text = normalize(title);
  if (/veicul|compartimentos suspeitos/.test(text)) return "vehicles";
  if (/capacidade final|carga final/.test(text)) return "capacity";
  if (/marcas|trajeto/.test(text)) return "marks";
  if (/lacre|cubic|cubo/.test(text)) return "cube";
  if (/suporte|triangular|prismatic/.test(text)) return "prism";
  if (/caixas|embalagem/.test(text)) return "crate";
  if (/cofre|dimensoes/.test(text)) return "safe";
  const context = normalize(description);
  if (order <= 7 && /cofre|veiculo|caixa|marca|lacre|triangular|compartimento/.test(context)) {
    return (["safe", "vehicles", "crate", "marks", "cube", "prism", "capacity"] as SceneKind[])[order - 1];
  }
  return "generic";
}

function dimensionsFrom(text: string): Dimensions | null {
  const match = text.match(/(\d+)\s*(?:cm)?\s*[×x]\s*(\d+)\s*(?:cm)?\s*[×x]\s*(\d+)\s*cm/i);
  if (!match) return null;
  return [Number(match[1]), Number(match[3]), Number(match[2])];
}

function scaled([length, height, width]: Dimensions): Dimensions {
  return [length * unit, height * unit, width * unit];
}

function solidBox(
  parent: THREE.Object3D,
  dimensions: Dimensions,
  center: Dimensions,
  color = 0x37383a,
  edge = 0xe1b7b4,
  opacity = 1,
) {
  const geometry = new THREE.BoxGeometry(...dimensions);
  const material = new THREE.MeshStandardMaterial({
    color, metalness: .55, roughness: .37, transparent: opacity < 1, opacity,
    depthWrite: opacity === 1, side: THREE.DoubleSide,
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(...center);
  parent.add(mesh);
  const edges = new THREE.LineSegments(
    new THREE.EdgesGeometry(geometry),
    new THREE.LineBasicMaterial({ color: edge, transparent: true, opacity: opacity < 1 ? .78 : .9 }),
  );
  edges.position.copy(mesh.position);
  parent.add(edges);
  return mesh;
}

function measureRails(parent: THREE.Object3D, [length, height, width]: Dimensions) {
  const rail = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(-length / 2, -.13, width / 2 + .23),
    new THREE.Vector3(length / 2, -.13, width / 2 + .23),
    new THREE.Vector3(length / 2 + .24, 0, width / 2 + .24),
    new THREE.Vector3(length / 2 + .24, height, width / 2 + .24),
    new THREE.Vector3(-length / 2 - .22, 0, -width / 2),
    new THREE.Vector3(-length / 2 - .22, 0, width / 2),
  ]);
  parent.add(new THREE.LineSegments(rail, new THREE.LineBasicMaterial({ color: 0xe63946 })));
}

function vault(parent: THREE.Object3D, raw: Dimensions = safe, transparent = false) {
  const [length, height, width] = scaled(raw);
  solidBox(parent, [length, height, width], [0, height / 2, 0], transparent ? 0x7c7674 : 0x343638, transparent ? 0xf1e8e6 : 0xc99a9a, transparent ? .13 : 1);
  if (!transparent) {
    solidBox(parent, [length * .87, height * .82, .10], [0, height / 2, width / 2 + .06], 0x1c1e20, 0xe63946);
    const dial = new THREE.Mesh(
      new THREE.TorusGeometry(Math.min(length, height) * .115, .035, 10, 32),
      new THREE.MeshStandardMaterial({ color: 0xd7c8c5, metalness: .85, roughness: .27 }),
    );
    dial.position.set(0, height / 2, width / 2 + .15);
    parent.add(dial);
    solidBox(parent, [.56, .055, .08], [0, height / 2, width / 2 + .18], 0x9e9a98, 0xf1e8e6);
    solidBox(parent, [.055, .56, .08], [0, height / 2, width / 2 + .18], 0x9e9a98, 0xf1e8e6);
    for (const y of [height * .24, height * .76]) {
      solidBox(parent, [.11, .27, .12], [length * .47, y, width / 2 + .1], 0x8b1e25, 0xe63946);
    }
  }
  measureRails(parent, [length, height, width]);
  return { height, extent: Math.max(length, width, height) };
}

function cargo(parent: THREE.Object3D, raw: Dimensions, withSafe: boolean) {
  const [length, height, width] = scaled(raw);
  solidBox(parent, [length, height, width], [0, height / 2, 0], 0x762d35, 0xe7747d, .095);
  solidBox(parent, [length, .06, width], [0, .03, 0], 0x36292b, 0x965159);
  if (withSafe) vault(parent, safe, true);
  measureRails(parent, [length, height, width]);
  return { height: Math.max(height, safe[1] * unit), extent: Math.max(length, width, height) };
}

function crate(parent: THREE.Object3D, offset = 0) {
  const [length, height, width] = scaled([60, 30, 40]);
  const group = new THREE.Group();
  group.position.x = offset;
  parent.add(group);
  solidBox(group, [length, height, width], [0, height / 2, 0], 0x51403b, 0xe6c7b9);
  for (const x of [-length * .34, length * .34]) {
    solidBox(group, [.09, height + .015, width + .02], [x, height / 2, 0], 0x8b1e25, 0xf1767e);
  }
  measureRails(group, [length, height, width]);
  return { height, extent: Math.max(length, width) };
}

function seal(parent: THREE.Object3D) {
  const side = 20 * unit;
  solidBox(parent, [side, side, side], [0, side / 2, 0], 0x71272e, 0xff979a);
  solidBox(parent, [.08, side + .01, side + .01], [0, side / 2, 0], 0xb44a52, 0xf1e8e6);
  measureRails(parent, [side, side, side]);
  return { height: side, extent: side };
}

function triangularSupport(parent: THREE.Object3D) {
  const base = 30 * unit, height = 40 * unit, depth = 60 * unit;
  const shape = new THREE.Shape();
  shape.moveTo(0, 0);
  shape.lineTo(base, 0);
  shape.lineTo(0, height);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: false, steps: 1 });
  geometry.translate(-base / 2, 0, -depth / 2);
  parent.add(new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({
    color: 0x67262d, metalness: .4, roughness: .47, side: THREE.DoubleSide,
  })));
  parent.add(new THREE.LineSegments(new THREE.EdgesGeometry(geometry), new THREE.LineBasicMaterial({ color: 0xf1aaa9 })));
  measureRails(parent, [base, height, depth]);
  return { height, extent: depth };
}

function floorMarks(parent: THREE.Object3D) {
  const [length, height, width] = scaled(safe);
  const outline = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(-length / 2, .025, -width / 2),
    new THREE.Vector3(length / 2, .025, -width / 2),
    new THREE.Vector3(length / 2, .025, width / 2),
    new THREE.Vector3(-length / 2, .025, width / 2),
  ]);
  parent.add(new THREE.LineLoop(outline, new THREE.LineBasicMaterial({ color: 0xe63946 })));
  solidBox(parent, [length, .035, width], [0, .015, 0], 0x8b1e25, 0xe63946, .24);
  vault(parent, safe, true);
  return { height, extent: length };
}

function buildModel(parent: THREE.Object3D, kind: SceneKind, selectedVehicle: string, selectedPart: CargoPart, generic: Dimensions | null) {
  if (kind === "vehicles") return cargo(parent, vehicles[selectedVehicle], true);
  if (kind === "capacity") {
    if (selectedPart === "cargo") return cargo(parent, vehicles.B, false);
    if (selectedPart === "safe") return vault(parent);
    if (selectedPart === "boxes") {
      const left = crate(parent, -1.18);
      crate(parent, 1.18);
      return { height: left.height, extent: 4.5 };
    }
    if (selectedPart === "seal") return seal(parent);
    return triangularSupport(parent);
  }
  if (kind === "safe") return vault(parent);
  if (kind === "crate") return crate(parent);
  if (kind === "marks") return floorMarks(parent);
  if (kind === "cube") return seal(parent);
  if (kind === "prism") return triangularSupport(parent);
  const raw = generic ?? [60, 30, 40];
  const [length, height, width] = scaled(raw);
  solidBox(parent, [length, height, width], [0, height / 2, 0], 0x593237, 0xe5b9b7);
  measureRails(parent, [length, height, width]);
  return { height, extent: Math.max(length, width, height) };
}

export default function GeometryScene({ title, description, order }: { title: string; description: string; order: number }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const controlsRef = useRef<Controls | null>(null);
  const [unsupported, setUnsupported] = useState(false);
  const [vehicle, setVehicle] = useState("A");
  const [part, setPart] = useState<CargoPart>("cargo");
  const kind = identify(title, description, order);
  const generic = dimensionsFrom(description + " " + title);
  const activePart = parts.find(item => item.id === part) ?? parts[0];
  const measures = kind === "vehicles"
    ? [`Compartimento ${vehicle}: ${vehicle === "A" ? "95 × 75 × 60" : vehicle === "B" ? "140 × 110 × 100" : "120 × 90 × 60"} cm`, "Cofre: 100 × 80 × 70 cm"]
    : kind === "capacity" ? [activePart.measures]
    : kind === "safe" || kind === "marks" ? ["Comprimento: 100 cm", "Largura: 80 cm", ...(kind === "safe" ? ["Altura: 70 cm"] : [])]
    : kind === "crate" ? ["Comprimento: 60 cm", "Largura: 40 cm", "Altura: 30 cm"]
    : kind === "cube" ? ["Aresta: 20 cm"]
    : kind === "prism" ? ["Cateto: 30 cm", "Cateto: 40 cm", "Comprimento: 60 cm"]
    : [generic ? `Medidas informadas: ${generic[0]} × ${generic[2]} × ${generic[1]} cm` : "Modelo ilustrativo · consulte as medidas do enunciado"];

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    let renderer: THREE.WebGLRenderer;
    try {
      renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: "low-power" });
    } catch {
      setUnsupported(true);
      return;
    }
    setUnsupported(false);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    const scene = new THREE.Scene();
    scene.add(new THREE.AmbientLight(0xf1e8e6, 1.3));
    const key = new THREE.DirectionalLight(0xffe2d8, 2.5);
    key.position.set(-4, 8, 7);
    scene.add(key);
    const alarm = new THREE.PointLight(0xe63946, 34, 15);
    alarm.position.set(4, 3, -3);
    scene.add(alarm);
    const model = new THREE.Group();
    scene.add(model);
    const bounds = buildModel(model, kind, vehicle, part, generic);
    const grid = new THREE.GridHelper(Math.max(10, bounds.extent * 2.1), 12, 0x76363d, 0x39292b);
    grid.position.y = -.045;
    const gridMaterial = grid.material as THREE.Material;
    gridMaterial.transparent = true;
    gridMaterial.opacity = .48;
    scene.add(grid);
    const camera = new THREE.PerspectiveCamera(38, 1, .1, 100);
    const target = new THREE.Vector3(0, Math.max(.38, bounds.height * .47), 0);
    const baseDistance = Math.max(2.8, bounds.extent * 1.85);
    let distance = baseDistance, yaw = .68, pitch = .42;
    const render = () => {
      const horizontal = distance * Math.cos(pitch);
      camera.position.set(target.x + horizontal * Math.sin(yaw), target.y + distance * Math.sin(pitch), target.z + horizontal * Math.cos(yaw));
      camera.lookAt(target);
      renderer.render(scene, camera);
    };
    const resize = () => {
      const width = Math.max(1, canvas.clientWidth), height = Math.max(1, canvas.clientHeight);
      renderer.setSize(width, height, false);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      render();
    };
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    resize();
    controlsRef.current = {
      rotate: angle => { yaw += angle; render(); },
      zoom: delta => { distance = Math.max(baseDistance * .65, Math.min(baseDistance * 1.8, distance + delta)); render(); },
      reset: () => { yaw = .68; pitch = .42; distance = baseDistance; render(); },
    };
    let last: { x: number; y: number } | null = null;
    const down = (event: PointerEvent) => {
      last = { x: event.clientX, y: event.clientY };
      canvas.setPointerCapture(event.pointerId);
      canvas.style.cursor = "grabbing";
    };
    const move = (event: PointerEvent) => {
      if (!last) return;
      yaw += (event.clientX - last.x) * .008;
      pitch = Math.max(-.15, Math.min(1.12, pitch + (event.clientY - last.y) * .006));
      last = { x: event.clientX, y: event.clientY };
      render();
    };
    const up = () => { last = null; canvas.style.cursor = "grab"; };
    const wheel = (event: WheelEvent) => { event.preventDefault(); controlsRef.current?.zoom(Math.sign(event.deltaY) * .45); };
    const keyboard = (event: KeyboardEvent) => {
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        event.preventDefault(); controlsRef.current?.rotate(event.key === "ArrowLeft" ? -.18 : .18);
      } else if (event.key === "+" || event.key === "=" || event.key === "-") {
        event.preventDefault(); controlsRef.current?.zoom(event.key === "-" ? .4 : -.4);
      }
    };
    canvas.addEventListener("pointerdown", down);
    canvas.addEventListener("pointermove", move);
    canvas.addEventListener("pointerup", up);
    canvas.addEventListener("pointercancel", up);
    canvas.addEventListener("wheel", wheel, { passive: false });
    canvas.addEventListener("keydown", keyboard);
    return () => {
      observer.disconnect();
      canvas.removeEventListener("pointerdown", down);
      canvas.removeEventListener("pointermove", move);
      canvas.removeEventListener("pointerup", up);
      canvas.removeEventListener("pointercancel", up);
      canvas.removeEventListener("wheel", wheel);
      canvas.removeEventListener("keydown", keyboard);
      controlsRef.current = null;
      scene.traverse(object => {
        if (object instanceof THREE.Mesh || object instanceof THREE.Line || object instanceof THREE.LineSegments) {
          object.geometry.dispose();
          const materials = Array.isArray(object.material) ? object.material : [object.material];
          materials.forEach(material => material.dispose());
        }
      });
      renderer.dispose();
    };
  }, [kind, vehicle, part, description]);

  return <section className="geometry-view" aria-label={`Modelo 3D do desafio: ${title}`}>
    <div className="geometry-view-head">
      <span className="eyebrow">RECONSTITUIÇÃO 3D · PERÍCIA</span>
      <span className="geometry-hint">Arraste para girar · use os controles para ampliar</span>
    </div>
    {kind === "vehicles" && <div className="geometry-switch" aria-label="Comparar compartimentos dos veículos">
      {Object.keys(vehicles).map(code => <button type="button" key={code} className={vehicle === code ? "active" : ""} onClick={() => setVehicle(code)} aria-pressed={vehicle === code}>Visualizar veículo {code}</button>)}
    </div>}
    {kind === "capacity" && <div className="geometry-switch" aria-label="Inspecionar peças da carga">
      {parts.map(item => <button type="button" key={item.id} className={part === item.id ? "active" : ""} onClick={() => setPart(item.id)} aria-pressed={part === item.id}>{item.label}</button>)}
    </div>}
    <div className="geometry-stage">
      <canvas ref={canvasRef} tabIndex={0} aria-label={`Modelo 3D interativo: ${title}. Use as setas para girar e as teclas mais e menos para ampliar.`} />
      {unsupported && <div className="geometry-fallback">A visualização 3D não está disponível neste dispositivo. Consulte as medidas do enunciado.</div>}
      <div className="geometry-controls" aria-label="Controles da visualização 3D">
        <button type="button" onClick={() => controlsRef.current?.rotate(-Math.PI / 8)} aria-label="Girar modelo para a esquerda">↶</button>
        <button type="button" onClick={() => controlsRef.current?.rotate(Math.PI / 8)} aria-label="Girar modelo para a direita">↷</button>
        <button type="button" onClick={() => controlsRef.current?.zoom(-.5)} aria-label="Ampliar modelo"><Plus size={16} /></button>
        <button type="button" onClick={() => controlsRef.current?.zoom(.5)} aria-label="Afastar modelo"><Minus size={16} /></button>
        <button type="button" onClick={() => controlsRef.current?.reset()} aria-label="Restaurar posição do modelo"><RotateCcw size={15} /></button>
      </div>
    </div>
    <div className="geometry-measures">{measures.map(measure => <span key={measure}>{measure}</span>)}</div>
    {(kind === "vehicles" || kind === "capacity" || kind === "generic") && <p className="geometry-note">
      {kind === "vehicles" ? "A forma clara representa o cofre. Compare as três medidas antes de responder."
        : kind === "capacity" ? "Peças exibidas separadamente para inspeção. Esta visualização não representa o arranjo físico da carga."
        : "Representação ilustrativa; use sempre os dados do enunciado para calcular."}
    </p>}
  </section>;
}
