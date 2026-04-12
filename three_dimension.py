import difflib
import math
import re
from contextlib import asynccontextmanager
from typing import Dict, List, Optional, Tuple

import networkx as nx
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from pyproj import Transformer

from db import supabase

FLOOR_CHANGE_PENALTY_BY_TYPE = {
    'stairs': 20.0,
    'elevator': 10.0,
    'escalator': 15.0,
}
DEFAULT_EDGE_TYPE = 'corridor'
DEFAULT_OPERATIONAL_FLOOR = 3


def choose_utm_epsg(lat: float, lon: float) -> str:
    zone = int((lon + 180) / 6) + 1
    return f'EPSG:{32600 + zone}' if lat >= 0 else f'EPSG:{32700 + zone}'


def normalize_name(value: str) -> str:
    return re.sub(r'[^a-z0-9]+', '', value.strip().lower())


class RouteRequest(BaseModel):
    user_lat: float
    user_lon: float
    target_name: str
    user_floor: int = DEFAULT_OPERATIONAL_FLOOR
    target_floor: int = DEFAULT_OPERATIONAL_FLOOR


class IndoorRouter:
    def __init__(
        self,
        source_crs: str = 'EPSG:4326',
        target_crs: Optional[str] = None,
    ):
        self.source_crs = source_crs
        self.target_crs = target_crs
        self.nodes: Dict[str, dict] = {}
        self.G = nx.Graph()

        raw_nodes = self._load_nodes_db()
        raw_edges = self._load_edges_db()

        if not raw_nodes:
            raise ValueError("No nodes found in the Supabase 'nodes' table.")
        if not raw_edges:
            raise ValueError("No edges found in the Supabase 'edges' table.")

        if not self.target_crs:
            lat0, lon0 = self._pick_anchor(raw_nodes)
            self.target_crs = choose_utm_epsg(lat0, lon0)

        self.fwd = Transformer.from_crs(
            self.source_crs,
            self.target_crs,
            always_xy=True,
        )
        self.inv = Transformer.from_crs(
            self.target_crs,
            self.source_crs,
            always_xy=True,
        )

        self._build_nodes(raw_nodes)
        self._build_edges(raw_edges)

    def _pick_anchor(self, raw_nodes: List[dict]) -> Tuple[float, float]:
        lats = [float(row['lat']) for row in raw_nodes]
        lons = [float(row['lon']) for row in raw_nodes]
        return (sum(lats) / len(lats), sum(lons) / len(lons))

    def _load_nodes_db(self) -> List[dict]:
        response = supabase.table('nodes').select('*').execute()
        return response.data or []

    def _load_edges_db(self) -> List[dict]:
        response = supabase.table('edges').select('*').execute()
        return response.data or []

    def _build_nodes(self, raw_nodes: List[dict]) -> None:
        lons = [float(row['lon']) for row in raw_nodes]
        lats = [float(row['lat']) for row in raw_nodes]
        xs, ys = self.fwd.transform(lons, lats)

        for row, x, y in zip(raw_nodes, xs, ys):
            node_id = row['id']
            node = {
                'id': node_id,
                'name': row.get('name', node_id),
                'category': row.get('category', ''),
                'lat': float(row['lat']),
                'lon': float(row['lon']),
                'x': float(x),
                'y': float(y),
                'floor': int(row['floor']),
            }
            self.nodes[node_id] = node
            self.G.add_node(node_id, **node)

    def _build_edges(self, raw_edges: List[dict]) -> None:
        for row in raw_edges:
            u = row['u']
            v = row['v']
            edge_type = (row.get('type') or DEFAULT_EDGE_TYPE).strip().lower()
            base_weight = (
                float(row['weight'])
                if row.get('weight') not in (None, '')
                else None
            )

            if u not in self.nodes or v not in self.nodes:
                continue

            node_a = self.nodes[u]
            node_b = self.nodes[v]
            weight = self._edge_weight(node_a, node_b, edge_type, base_weight)
            self.G.add_edge(u, v, weight=weight, type=edge_type)

    def _edge_weight(
        self,
        node_a: dict,
        node_b: dict,
        edge_type: str,
        base_weight: Optional[float],
    ) -> float:
        if base_weight is not None:
            weight = float(base_weight)
        else:
            weight = math.hypot(node_a['x'] - node_b['x'], node_a['y'] - node_b['y'])

        if node_a['floor'] != node_b['floor']:
            weight += FLOOR_CHANGE_PENALTY_BY_TYPE.get(edge_type, 15.0)
        elif edge_type in FLOOR_CHANGE_PENALTY_BY_TYPE:
            weight += FLOOR_CHANGE_PENALTY_BY_TYPE[edge_type]

        return weight

    def _nearest_node_id(
        self,
        x: float,
        y: float,
        prefer_floor: int = DEFAULT_OPERATIONAL_FLOOR,
    ) -> Optional[str]:
        best_id = None
        best_distance = float('inf')

        candidate_nodes = list(self.G.nodes(data=True))
        same_floor_candidates = [
            (node_id, data)
            for node_id, data in candidate_nodes
            if data['floor'] == prefer_floor
        ]
        if same_floor_candidates:
            candidate_nodes = same_floor_candidates

        for node_id, data in candidate_nodes:
            distance = math.hypot(data['x'] - x, data['y'] - y)
            if distance < best_distance:
                best_distance = distance
                best_id = node_id

        return best_id

    def _nodes_for_floor(self, floor: int) -> List[Tuple[str, dict]]:
        return [
            (node_id, data)
            for node_id, data in self.G.nodes(data=True)
            if data['floor'] == floor
        ]

    def _find_target_node(
        self,
        target_name: str,
        target_floor: int = DEFAULT_OPERATIONAL_FLOOR,
    ) -> Optional[str]:
        raw_query = target_name.strip().lower()
        normalized_query = normalize_name(target_name)
        floor_nodes = self._nodes_for_floor(target_floor)

        for node_id, data in floor_nodes:
            if data['name'].strip().lower() == raw_query:
                return node_id

        for node_id, data in floor_nodes:
            if normalize_name(data['name']) == normalized_query:
                return node_id

        for node_id, data in floor_nodes:
            if raw_query and raw_query in data['name'].strip().lower():
                return node_id

        for node_id, data in floor_nodes:
            if normalized_query and normalized_query in normalize_name(data['name']):
                return node_id

        best_match_id = None
        best_score = 0.0
        for node_id, data in floor_nodes:
            score = difflib.SequenceMatcher(
                None,
                normalized_query,
                normalize_name(data['name']),
            ).ratio()
            if score > best_score:
                best_score = score
                best_match_id = node_id

        if best_match_id is not None and best_score >= 0.72:
            return best_match_id

        return None

    def suggest_targets(self, target_name: str, limit: int = 5) -> List[str]:
        floor_names = sorted(
            {
                data['name']
                for _, data in self.G.nodes(data=True)
                if data['floor'] == DEFAULT_OPERATIONAL_FLOOR
            }
        )
        direct_matches = difflib.get_close_matches(
            target_name,
            floor_names,
            n=limit,
            cutoff=0.3,
        )
        if direct_matches:
            return direct_matches

        normalized_floor_map = {
            normalize_name(name): name
            for name in floor_names
        }
        normalized_matches = difflib.get_close_matches(
            normalize_name(target_name),
            list(normalized_floor_map.keys()),
            n=limit,
            cutoff=0.3,
        )
        return [normalized_floor_map[key] for key in normalized_matches]

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
        user_floor: int = DEFAULT_OPERATIONAL_FLOOR,
        target_floor: int = DEFAULT_OPERATIONAL_FLOOR,
    ) -> dict:
        user_x, user_y = self.project_wgs84_to_xy(user_lon, user_lat)
        start_id = self._nearest_node_id(user_x, user_y, prefer_floor=user_floor)
        if start_id is None:
            raise ValueError('Unable to determine the closest indoor node.')

        target_id = self._find_target_node(target_name, target_floor)
        if target_id is None:
            suggestions = self.suggest_targets(target_name)
            available_targets = ', '.join(
                sorted(name for _, name in {
                    (data['id'], data['name'])
                    for _, data in self.G.nodes(data=True)
                    if data['floor'] == target_floor
                })
            )
            message = f'Target not found on floor {target_floor}: {target_name}'
            if suggestions:
                message += f". Suggestions: {', '.join(suggestions)}"
            else:
                message += f'. Available floor-{target_floor} targets: {available_targets}'
            raise ValueError(message)

        try:
            path = nx.shortest_path(
                self.G,
                source=start_id,
                target=target_id,
                weight='weight',
                method='dijkstra',
            )
        except nx.NetworkXNoPath as error:
            raise ValueError('No route could be found to the selected target.') from error

        total_distance = nx.path_weight(self.G, path, weight='weight')
        instructions = self._build_instructions(path)

        coordinates = []
        for node_id in path:
            node = self.G.nodes[node_id]
            lon, lat = self.project_xy_to_wgs84(node['x'], node['y'])
            coordinates.append(
                {
                    'id': node_id,
                    'name': node['name'],
                    'lat': lat,
                    'lon': lon,
                    'floor': node['floor'],
                }
            )

        start_node = self.G.nodes[start_id]
        target_node = self.G.nodes[target_id]
        return {
            'start': start_node['name'],
            'start_id': start_id,
            'start_name': start_node['name'],
            'user_floor': user_floor,
            'target': target_node['name'],
            'target_id': target_id,
            'target_name': target_node['name'],
            'target_floor': target_floor,
            'distance_m': round(total_distance, 2),
            'path': coordinates,
            'instructions': instructions,
            'crs': self.target_crs,
        }

    def _build_instructions(self, path: List[str]) -> List[str]:
        start_node = self.G.nodes[path[0]]
        instructions = [
            f"Start near {start_node['name']} on floor {start_node['floor']}."
        ]

        for index in range(len(path) - 1):
            current_id, next_id = path[index], path[index + 1]
            current_node = self.G.nodes[current_id]
            next_node = self.G.nodes[next_id]
            edge = self.G.edges[current_id, next_id]
            segment_length = math.hypot(
                current_node['x'] - next_node['x'],
                current_node['y'] - next_node['y'],
            )

            if current_node['floor'] != next_node['floor']:
                instructions.append(
                    f"Take the {edge.get('type', 'transition')} from floor "
                    f"{current_node['floor']} to floor {next_node['floor']}."
                )
            else:
                instructions.append(
                    f"Walk about {int(round(segment_length))} m on floor "
                    f"{current_node['floor']} toward {next_node['name']}."
                )

        instructions.append(f"Arrive at {self.G.nodes[path[-1]]['name']}.")
        return instructions


def _get_router(app: FastAPI) -> IndoorRouter:
    router: Optional[IndoorRouter] = getattr(app.state, 'router', None)
    if router is None:
        raise HTTPException(status_code=503, detail='Router is not initialized.')
    return router


def _build_route_response(
    router: IndoorRouter,
    *,
    user_lat: float,
    user_lon: float,
    target_name: str,
    user_floor: int = DEFAULT_OPERATIONAL_FLOOR,
    target_floor: int = DEFAULT_OPERATIONAL_FLOOR,
) -> dict:
    effective_user_floor = DEFAULT_OPERATIONAL_FLOOR
    effective_target_floor = DEFAULT_OPERATIONAL_FLOOR

    try:
        return router.route(
            user_lon=user_lon,
            user_lat=user_lat,
            target_name=target_name,
            user_floor=effective_user_floor,
            target_floor=effective_target_floor,
        )
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.router = IndoorRouter(source_crs='EPSG:4326')
    yield
    app.state.router = None


app = FastAPI(title='NavU Indoor Navigation API', lifespan=lifespan)


@app.get('/health')
def health() -> dict:
    router = _get_router(app)
    return {
        'status': 'ok',
        'default_floor': DEFAULT_OPERATIONAL_FLOOR,
        'nodes': router.G.number_of_nodes(),
        'edges': router.G.number_of_edges(),
        'crs': router.target_crs,
    }


@app.get('/route')
def route_get(
    user_lat: float = Query(...),
    user_lon: float = Query(...),
    target_name: str = Query(...),
    user_floor: int = Query(DEFAULT_OPERATIONAL_FLOOR),
    target_floor: int = Query(DEFAULT_OPERATIONAL_FLOOR),
) -> dict:
    router = _get_router(app)
    return _build_route_response(
        router,
        user_lat=user_lat,
        user_lon=user_lon,
        target_name=target_name,
        user_floor=user_floor,
        target_floor=target_floor,
    )


@app.post('/route')
def route_post(request: RouteRequest) -> dict:
    router = _get_router(app)
    return _build_route_response(
        router,
        user_lat=request.user_lat,
        user_lon=request.user_lon,
        target_name=request.target_name,
        user_floor=request.user_floor,
        target_floor=request.target_floor,
    )
