from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from three_dimension import IndoorRouter

# -----------------------
# Initialize router engine
# -----------------------
router_engine = IndoorRouter(
    source_crs="EPSG:4326"
)

# -----------------------
# FastAPI app + CORS
# -----------------------
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------
# Request model
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
        return router_engine.route(
            user_lon=req.user_lon,
            user_lat=req.user_lat,
            target_name=req.target_name,
            user_floor=req.user_floor,
            target_floor=req.target_floor,
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# -----------------------
# Run server
# -----------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)