from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from three_dimension import IndoorRouter  # your existing router

# -----------------------
# Initialize router engine
# -----------------------
router_engine = IndoorRouter(
    nodes_path="nodes.csv",
    edges_path="edges.csv",
    source_crs="EPSG:4326",   # WGS84 lat/lon
)

# -----------------------
# FastAPI app + CORS
# -----------------------
app = FastAPI()

# Allow requests from your phone / emulator
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # in production, restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------
# Pydantic request model
# -----------------------
class RouteRequest(BaseModel):
    user_lat: float
    user_lon: float
    target_name: str
    user_floor: Optional[int] = None
    target_floor: Optional[int] = None

# -----------------------
# Route endpoint
# -----------------------
@app.post("/route")
def get_route(req: RouteRequest):
    try:
        result = router_engine.route(
            user_lon=req.user_lon,
            user_lat=req.user_lat,
            target_name=req.target_name,
            user_floor=req.user_floor,
            target_floor=req.target_floor,
        )
        # result is already a dict with path + instructions in three_dimension.py
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# Optional: run with python server.py (instead of uvicorn command)
if _name_ == "_main_":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
