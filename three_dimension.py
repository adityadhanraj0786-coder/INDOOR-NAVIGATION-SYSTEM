# three_dimension.py
# Indoor routing with floor-aware penalties, CLI + FastAPI (lifespan) in one file.
#
# Usage (CLI):
#   python three_dimension.py --nodes nodes.csv --edges edges.csv \
#     --user-lat 28.61301 --user-lon 77.20905 --target-name "Room 302" --user-floor 0
#
# Usage (API):
#   uvicorn three_dimension:app --reload
#   GET /route?user_lat=28.61301&user_lon=77.20905&target_name=Room%20302&user_floor=0
#
# Requirements:
#   pip install pyproj networkx fastapi uvicorn

import csv
import math
import json
import argparse
from typing import Dict, Tuple, List, Optional

import networkx as nx
from pyproj import Transformer
from contextlib import asynccontextmanager
from fastapi import FastAPI, Query

# ------------------------------
# Config
# ------------------------------

# Penalties for transitions; tune per venue and mobility needs
FLOOR_CHANGE_PENALTY_BY_TYPE = {
    "stairs": 20.0,     # meters-equivalent
    "elevator": 10.0,   # meters-equivalent
    "escalator": 15.0,  # if used
}
DEFAULT_EDGE_TYPE = "corridor"  # default for non-specified types


# ------------------------------
# CRS helpers
# ------------------------------

def choose_utm_epsg(lat: float, lon: float) -> str:
    """
    Choose a UTM EPSG code from latitude/longitude (WGS84).
    Northern hemisphere → EPSG:326xx; Southern → EPSG:327xx
    """
    zone = int((lon + 180) / 6) + 1
    if lat >= 0:
        return f"EPSG:{32600 + zone}"
    else:
        return f"EPSG:{32700 + zone}"


# ------------------------------
# Indoor Router
# ------------------------------

class IndoorRouter:
    def __init__(
        self,
        nodes_path: str,
        edges_path: str,
        source_crs: str = "EPSG:4326",       # WGS84 (lat, lon)
        target_crs: Optional[str] = None,    # e.g., EPSG:32644 or EPSG:3857
        anchor_lat: Optional[float] = None,
        anchor_lon: Optional[float] = None,
    ):
        self.nodes_path = nodes_path
        self.edges_path = edges_path
        self.source_crs = source_crs
        self.nodes: Dict[str, dict] = {}
        self.G = nx.Graph()
        self.target_crs = target_crs
        self.anchor_lat = anchor_lat
        self.anchor_lon = anchor_lon

        raw_nodes = self._load_nodes_csv(nodes_path)
        raw_edges = self._load_edges_csv(edges_path)

        if not self.target_crs:
            lat0, lon0 = self._pick_anchor(raw_nodes)
            self.target_crs = choose_utm_epsg(lat0, lon0)

        # always_xy=True ensures (lon, lat) order going in/out for geographic CRS
        self.fwd = Transformer.from_crs(self.source_crs, self.target_crs, always_xy=True)
        self.inv = Transformer.from_crs(self.target_crs, self.source_crs, always_xy=True)

        self._build_nodes(raw_nodes)
        self._build_edges(raw_edges)

    def _pick_anchor(self, raw_nodes: List[dict]) -> Tuple[float, float]:
        if self.anchor_lat is not None and self.anchor_lon is not None:
            return self.anchor_lat, self.anchor_lon
        lats = [float(r["lat"]) for r in raw_nodes]
        lons = [float(r["lon"]) for r in raw_nodes]
        return (sum(lats) / len(lats), sum(lons) / len(lons))

    def _load_nodes_csv(self, path: str) -> List[dict]:
        rows = []
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for r in reader:
                rows.append(r)
        return rows

    def _load_edges_csv(self, path: str) -> List[dict]:
        rows = []
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for r in reader:
                rows.append(r)
        return rows

    def _build_nodes(self, raw_nodes: List[dict]):
        lons = [float(r["lon"]) for r in raw_nodes]
        lats = [float(r["lat"]) for r in raw_nodes]
        xs, ys = self.fwd.transform(lons, lats)
        for r, x, y in zip(raw_nodes, xs, ys):
            nid = r["id"]
            self.nodes[nid] = {
                "id": nid,
                "name": r.get("name", nid),
                "category": r.get("category", ""),
                "lat": float(r["lat"]),
                "lon": float(r["lon"]),
                "x": float(x),
                "y": float(y),
                "floor": int(r["floor"]),
            }
            self.G.add_node(nid, **self.nodes[nid])

    def _edge_weight(self, a: dict, b: dict, e_type: str, base_weight: Optional[float]) -> float:
        if base_weight is not None:
            w = float(base_weight)
        else:
            w = math.hypot(a["x"] - b["x"], a["y"] - b["y"])
        if a["floor"] != b["floor"]:
            w += FLOOR_CHANGE_PENALTY_BY_TYPE.get(e_type, 15.0)
        elif e_type in FLOOR_CHANGE_PENALTY_BY_TYPE:
            w += FLOOR_CHANGE_PENALTY_BY_TYPE[e_type]
        return w

    def _build_edges(self, raw_edges: List[dict]):
        for r in raw_edges:
            u = r["u"]
            v = r["v"]
            e_type = (r.get("type") or DEFAULT_EDGE_TYPE).strip().lower()
            base_w = float(r["weight"]) if r.get("weight") not in (None, "",) else None
            if u not in self.nodes or v not in self.nodes:
                continue
            a = self.nodes[u]
            b = self.nodes[v]
            w = self._edge_weight(a, b, e_type, base_w)
            self.G.add_edge(u, v, weight=w, type=e_type)

    # ---- Query / routing ----

    def _nearest_node_id(self, x: float, y: float, prefer_floor: Optional[int] = None) -> str:
        best = None
        best_d = float("inf")
        for nid, data in self.G.nodes(data=True):
            bias = 0.0 if (prefer_floor is None or data["floor"] == prefer_floor) else 5.0
            d = math.hypot(data["x"] - x, data["y"] - y) + bias
            if d < best_d:
                best_d = d
                best = nid
        return best

    def _find_target_node(self, target_name: str, target_floor: Optional[int] = None) -> Optional[str]:
        target_name_l = target_name.strip().lower()
        candidates = []
        for nid, data in self.G.nodes(data=True):
            if data["name"].strip().lower() == target_name_l:
                if target_floor is None or data["floor"] == target_floor:
                    candidates.append(nid)
        if candidates:
            return candidates[0]
        for nid, data in self.G.nodes(data=True):
            if target_name_l in data["name"].strip().lower():
                if target_floor is None or data["floor"] == target_floor:
                    return nid
        return None

    def project_wgs84_to_xy(self, lon: float, lat: float) -> Tuple[float, float]:
        x, y = self.fwd.transform(lon, lat)
        return float(x), float(y)

    def project_xy_to_wgs84(self, x: float, y: float) -> Tuple[float, float]:
        lon, lat = self.inv.transform(x, y)
        return float(lon), float(lat)

    def route(
        self,
        user_lon: float,
        user_lat: float,
        target_name: str,
        user_floor: Optional[int] = None,
        target_floor: Optional[int] = None,
    ) -> dict:
        ux, uy = self.project_wgs84_to_xy(user_lon, user_lat)
        start_id = self._nearest_node_id(ux, uy, prefer_floor=user_floor)

        target_id = self._find_target_node(target_name, target_floor)
        if target_id is None:
            raise ValueError(f"Target not found: {target_name}")

        path = nx.shortest_path(self.G, source=start_id, target=target_id, weight="weight", method="dijkstra")
        total = nx.path_weight(self.G, path, weight="weight")

        instr = self._build_instructions(path)

        coords = []
        for nid in path:
            n = self.G.nodes[nid]
            lon, lat = self.project_xy_to_wgs84(n["x"], n["y"])
            coords.append({"id": nid, "name": n["name"], "lat": lat, "lon": lon, "floor": n["floor"]})

        return {
            "start": start_id,
            "target": target_id,
            "distance_m": round(total, 2),
            "path": coords,
            "instructions": instr,
            "crs": self.target_crs,
        }

    def _build_instructions(self, path: List[str]) -> List[str]:
        out = []
        for i in range(len(path) - 1):
            u, v = path[i], path[i+1]
            a = self.G.nodes[u]
            b = self.G.nodes[v]
            e = self.G.edges[u, v]
            seg = math.hypot(a["x"] - b["x"], a["y"] - b["y"])
            if a["floor"] != b["floor"]:
                step = f"Use {e.get('type', 'transition')} from floor {a['floor']} to {b['floor']}."
            else:
                step = f"Walk {int(round(seg))} m on floor {a['floor']} towards {b['name']}."
            out.append(step)
        out.append(f"Arrived at {self.G.nodes[path[-1]]['name']}.")
        return out


# ------------------------------
# FastAPI app (lifespan)
# ------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    import os
    nodes_path = os.getenv("INDOOR_NODES", "nodes.csv")
    edges_path = os.getenv("INDOOR_EDGES", "edges.csv")
    source_crs = os.getenv("INDOOR_SOURCE_CRS", "EPSG:4326")
    target_crs = os.getenv("INDOOR_TARGET_CRS")  # optional
    app.state.router = IndoorRouter(
        nodes_path,
        edges_path,
        source_crs=source_crs,
        target_crs=target_crs,
    )
    yield
    app.state.router = None

app = FastAPI(lifespan=lifespan)

@app.get("/route")
def route(
    user_lat: float = Query(...),
    user_lon: float = Query(...),
    target_name: str = Query(...),
    user_floor: Optional[int] = Query(None),
    target_floor: Optional[int] = Query(None),
):
    router: IndoorRouter = app.state.router
    if router is None:
        return {"error": "Router not initialized"}
    try:
        return router.route(
            user_lon=user_lon,
            user_lat=user_lat,
            target_name=target_name,
            user_floor=user_floor,
            target_floor=target_floor,
        )
    except Exception as e:
        return {"error": str(e)}


# ------------------------------
# CLI entrypoint
# ------------------------------

def main():
    ap = argparse.ArgumentParser(description="Indoor routing (3+ floors) with floor-aware penalties.")
    ap.add_argument("--nodes", required=True, help="nodes.csv")
    ap.add_argument("--edges", required=True, help="edges.csv")
    ap.add_argument("--user-lat", type=float, required=True, help=28.61301)
    ap.add_argument("--user-lon", type=float, required=True, help=77.20905)
    ap.add_argument("--target-name", type=str, required=True, help="Target room/place name")
    ap.add_argument("--user-floor", type=int, default=None, help=0)
    ap.add_argument("--target-floor", type=int, default=None, help=3)
    ap.add_argument("--source-crs", type=str, default="EPSG:4326", help="Source CRS (default WGS84)")
    ap.add_argument("--target-crs", type=str, default=None, help="Target projected CRS (auto if omitted)")
    args = ap.parse_args()

    router = IndoorRouter(
        nodes_path=args.nodes,
        edges_path=args.edges,
        source_crs=args.source_crs,
        target_crs=args.target_crs,
    )

    res = router.route(
        user_lon=args.user_lon,
        user_lat=args.user_lat,
        target_name=args.target_name,
        user_floor=args.user_floor,
        target_floor=args.target_floor,
    )
    print(json.dumps(res, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()



