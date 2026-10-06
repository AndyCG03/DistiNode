import type { ComponentKind, ParamKey } from "@/sim/components";
import { buildTemplate, clampTraffic, EMPTY_DIAGRAM, makeNode, newId } from "./ops";
import type { DiagramActions, DiagramState, EdgeData, Notice, NodeData } from "./types";

/** Almacén del modo demo: estado inmutable + persistencia en localStorage. */
export class LocalStore {
  private state: DiagramState;
  private listeners = new Set<() => void>();
  private saveTimer: ReturnType<typeof setTimeout> | null = null;

  /** El modo demo muestra sus propios avisos del sistema (caos, sobrecarga). */
  private onNotice: ((n: Notice) => void) | null = null;

  setNoticeHandler(fn: ((n: Notice) => void) | null) {
    this.onNotice = fn;
  }

  constructor(private key: string) {
    this.state = load(key);
  }

  subscribe = (fn: () => void) => {
    this.listeners.add(fn);
    return () => {
      this.listeners.delete(fn);
    };
  };

  getSnapshot = () => this.state;

  private set(next: DiagramState) {
    this.state = next;
    for (const fn of this.listeners) fn();
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => {
      try {
        localStorage.setItem(this.key, JSON.stringify({ ...this.state, sim: { ...this.state.sim, running: false } }));
      } catch {
        // sin almacenamiento: el diagrama dura lo que la pestaña
      }
    }, 250);
  }

  private patchNode(id: string, patch: Partial<NodeData>) {
    const n = this.state.nodes[id];
    if (!n) return;
    this.set({ ...this.state, nodes: { ...this.state.nodes, [id]: { ...n, ...patch } } });
  }

  actions(): DiagramActions {
    const replace = (nodeList: NodeData[], edgeList: EdgeData[], sim?: Partial<DiagramState["sim"]>) => {
      const nodes: Record<string, NodeData> = {};
      const edges: Record<string, EdgeData> = {};
      for (const nd of nodeList) nodes[nd.id] = nd;
      for (const e of edgeList) edges[e.id] = e;
      this.set({ ...this.state, nodes, edges, sim: { ...this.state.sim, ...sim } });
    };
    return {
      addNode: (kind: ComponentKind, x: number, y: number) => {
        const node = makeNode(
          kind,
          x,
          y,
          Object.values(this.state.nodes).map((n) => n.label),
        );
        this.set({ ...this.state, nodes: { ...this.state.nodes, [node.id]: node } });
        return { id: node.id, label: node.label };
      },
      moveNode: (id, x, y) => this.patchNode(id, { x: Math.round(x), y: Math.round(y) }),
      removeElements: (nodeIds, edgeIds) => {
        const gone = new Set(nodeIds);
        const dropEdges = new Set(edgeIds);
        const nodes = Object.fromEntries(Object.entries(this.state.nodes).filter(([id]) => !gone.has(id)));
        const edges = Object.fromEntries(
          Object.entries(this.state.edges).filter(
            ([id, e]) => !dropEdges.has(id) && !gone.has(e.source) && !gone.has(e.target),
          ),
        );
        this.set({ ...this.state, nodes, edges });
      },
      connect: (source, target) => {
        if (source === target) return false;
        if (Object.values(this.state.edges).some((e) => e.source === source && e.target === target)) return false;
        const id = newId();
        this.set({ ...this.state, edges: { ...this.state.edges, [id]: { id, source, target } } });
        return true;
      },
      setParam: (id, key: ParamKey, value) => {
        const n = this.state.nodes[id];
        if (n) this.patchNode(id, { params: { ...n.params, [key]: value } });
      },
      setLabel: (id, label) => this.patchNode(id, { label: label.slice(0, 40) }),
      setNodeState: (id, patch) => this.patchNode(id, patch),
      setEdge: (id, patch) => {
        const e = this.state.edges[id];
        if (e) this.set({ ...this.state, edges: { ...this.state.edges, [id]: { ...e, ...patch } } });
      },
      setRunning: (running) => this.set({ ...this.state, sim: { ...this.state.sim, running } }),
      setTraffic: (traffic) => this.set({ ...this.state, sim: { ...this.state.sim, traffic: clampTraffic(traffic) } }),
      setSimOptions: (patch) => this.set({ ...this.state, sim: { ...this.state.sim, ...patch } }),
      loadTemplate: (t) => {
        const built = buildTemplate(t);
        replace(built.nodes, built.edges, { traffic: t.traffic });
      },
      replaceDiagram: (nodes, edges, sim) => replace(nodes, edges, sim),
      notify: () => {},
      announce: (text) => this.onNotice?.({ text, color: "var(--rojo)" }),
    };
  }
}

function load(key: string): DiagramState {
  try {
    const raw = typeof localStorage === "undefined" ? null : localStorage.getItem(key);
    if (!raw) return EMPTY_DIAGRAM;
    const parsed = JSON.parse(raw) as DiagramState;
    if (!parsed?.nodes || !parsed?.edges || !parsed?.sim) return EMPTY_DIAGRAM;
    return parsed;
  } catch {
    return EMPTY_DIAGRAM;
  }
}
